// Package main is the entry point for the Thesa BFF server.
// It wires all dependencies together and starts the HTTP server using Frame.
package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"path/filepath"

	"github.com/pitabwire/frame"
	"github.com/pitabwire/frame/security/interceptors/httptor"
	frameversion "github.com/pitabwire/frame/version"
	"github.com/pitabwire/util"

	"github.com/antinvestor/service-thesa/pkg/analytics"
	"github.com/antinvestor/service-thesa/pkg/capability"
	"github.com/antinvestor/service-thesa/pkg/command"
	"github.com/antinvestor/service-thesa/pkg/config"
	"github.com/antinvestor/service-thesa/pkg/definition"
	"github.com/antinvestor/service-thesa/pkg/invoker"
	"github.com/antinvestor/service-thesa/pkg/metadata"
	"github.com/antinvestor/service-thesa/pkg/openapi"
	"github.com/antinvestor/service-thesa/pkg/search"
	"github.com/antinvestor/service-thesa/pkg/transport"
)

func main() {
	configPath := flag.String("config", "config.yaml", "path to configuration file")
	flag.Parse()

	ctx := context.Background()
	log := util.Log(ctx)

	cfg, err := config.Load(*configPath)
	if err != nil {
		log.WithError(err).Fatal("configuration error")
	}

	// Service name defaults to "service-thesa" but can be overridden via
	// SERVICE_NAME env var (standard for all antinvestor services). Frame's
	// WithConfig option reads Name() from the config and applies it.
	if cfg.ServiceName == "" {
		cfg.ServiceName = "service-thesa"
	}

	// Load OpenAPI specs.
	oaIndex := openapi.NewIndex()
	specSources := buildSpecSources(cfg.Specs)
	if err := oaIndex.Load(specSources); err != nil {
		log.WithError(err).Fatal("OpenAPI index load failed")
	}

	// Load definitions.
	loader := definition.NewLoader()
	defs, err := loader.LoadAll(cfg.Definitions.Directories)
	if err != nil {
		log.WithError(err).Fatal("definition loading failed")
	}

	validator := definition.NewValidator()
	verrs := validator.Validate(defs, oaIndex)
	if len(verrs) > 0 {
		log.Fatal("definition validation failed",
			"error_count", len(verrs),
		)
	}

	registry := definition.NewRegistry(defs)

	// Create Frame service (provides HTTP client, telemetry, lifecycle,
	// and SecurityManager with authorization service access).
	ctx, svc := frame.NewServiceWithContext(ctx, frame.WithConfig(cfg))
	defer svc.Stop(ctx)
	log = svc.Log(ctx)

	httpClient := svc.HTTPClientManager().Client(ctx)
	authenticator := svc.SecurityManager().GetAuthenticator(ctx)

	// Capability resolver — checks each known capability against the
	// authorization service (Keto) using BatchCheck, which evaluates
	// OPL rules, role hierarchies, and computed permissions.
	authorizer := svc.SecurityManager().GetAuthorizer(ctx)
	capChecks := capability.CollectCapabilityChecks(defs, cfg.Services)
	evaluator := capability.NewKetoPolicyEvaluator(authorizer, capChecks)
	capResolver := capability.NewResolver(evaluator, cfg.Capability.Cache.TTL)

	// Build invoker registry.
	sdkHandlers := invoker.NewSDKHandlerRegistry()
	invokerReg := invoker.NewRegistry()
	invokerReg.Register(invoker.NewOpenAPIOperationInvoker(oaIndex, cfg.Services, httpClient))
	invokerReg.Register(invoker.NewSDKOperationInvoker(sdkHandlers))

	// Build providers.
	cmdExecutor := command.NewCommandExecutor(registry, invokerReg, oaIndex)
	actionProvider := metadata.NewActionProvider()
	menuProvider := metadata.NewMenuProvider(registry, invokerReg)
	pageProvider := metadata.NewPageProvider(registry, invokerReg, actionProvider)
	formProvider := metadata.NewFormProvider(registry, invokerReg, actionProvider)
	schemaProvider := metadata.NewSchemaProvider(registry)
	resourceProvider := metadata.NewResourceProvider(registry, invokerReg, oaIndex)
	searchProvider := search.NewSearchProvider(
		registry, invokerReg,
		cfg.Search.TimeoutPerProvider,
		cfg.Search.MaxResultsPerProvider,
	)
	lookupProvider := search.NewLookupProvider(
		registry, invokerReg,
		cfg.Lookup.Cache.TTL,
		cfg.Lookup.Cache.MaxEntries,
	)

	// Analytics engine — queries OTel metrics from the configured backend
	// (Prometheus, Mimir, Thanos, VictoriaMetrics, OpenObserve, etc.) when enabled.
	var analyticsEngine *analytics.Engine
	if cfg.Analytics.Enabled && cfg.Analytics.BackendURL != "" {
		var metricsBackend analytics.MetricsBackend
		backendType := cfg.Analytics.BackendType

		switch backendType {
		case "openobserve":
			ooClient := analytics.NewOpenObserveHTTPClient(
				cfg.Analytics.Username,
				cfg.Analytics.Password,
				httpClient.Transport,
			)
			metricsBackend = analytics.NewOpenObserveBackend(
				cfg.Analytics.BackendURL,
				cfg.Analytics.Org,
				ooClient,
			)
		case "uptrace":
			upClient := analytics.NewUptraceHTTPClient(
				cfg.Analytics.Token,
				httpClient.Transport,
			)
			metricsBackend = analytics.NewUptraceBackend(
				cfg.Analytics.BackendURL,
				upClient,
			)
		default:
			backendType = "prometheus"
			metricsBackend = analytics.NewPrometheusBackend(cfg.Analytics.BackendURL, httpClient)
		}

		analyticsEngine, err = analytics.NewEngine(metricsBackend, nil,
			analytics.WithCacheTTL(cfg.Analytics.CacheTTL),
			analytics.WithAllowedMetrics(cfg.Analytics.AllowedMetrics),
		)
		if err != nil {
			log.WithError(err).Fatal("analytics engine configuration error")
		}

		if err := analyticsEngine.Healthy(ctx); err != nil {
			log.WithError(err).Warn("metrics backend not reachable at startup")
		}

		log.Info("analytics engine enabled",
			"backend_type", backendType,
			"backend_url", cfg.Analytics.BackendURL,
		)
	}

	// Build HTTP router.
	authenticate := func(next http.Handler) http.Handler {
		return httptor.AuthenticationMiddleware(next, authenticator)
	}

	router := transport.NewRouter(transport.Dependencies{
		Config:             cfg,
		Authenticate:       authenticate,
		CapabilityResolver: capResolver,
		Registry:           registry,
		MenuProvider:       menuProvider,
		PageProvider:       pageProvider,
		FormProvider:       formProvider,
		SchemaProvider:     schemaProvider,
		ResourceProvider:   resourceProvider,
		CommandExecutor:    cmdExecutor,
		SearchProvider:     searchProvider,
		LookupProvider:     lookupProvider,
		AnalyticsEngine:    analyticsEngine,
		AppVersion:         frameversion.Version,
	})

	// Register handler and health checks with Frame.
	svc.Init(ctx, frame.WithHTTPHandler(router))

	svc.AddHealthCheck(frame.CheckerFunc(func() error {
		if len(registry.AllDomains()) == 0 {
			return fmt.Errorf("no definitions loaded")
		}
		return nil
	}))

	// Analytics reachability is reported at startup (log.Warn above) but not
	// gated on readiness. The BFF must keep serving every other route when the
	// metrics backend is unreachable or mis-authenticated — only /analytics/*
	// degrades.

	svc.AddHealthCheck(frame.CheckerFunc(func() error {
		for _, svcID := range buildSpecServiceIDs(specSources) {
			if len(oaIndex.AllOperationIDs(svcID)) > 0 {
				return nil
			}
		}
		if len(specSources) == 0 {
			return nil
		}
		return fmt.Errorf("no OpenAPI specs loaded")
	}))

	log.Info("server starting",
		"version", frameversion.Version,
		"commit", frameversion.Commit,
		"definitions", len(defs),
	)

	serverPort := fmt.Sprintf(":%d", cfg.Server.Port)
	if err := svc.Run(ctx, serverPort); err != nil {
		log.WithError(err).Fatal("server failed")
	}
}

func buildSpecSources(specsCfg config.SpecsConfig) []openapi.SpecSource {
	sources := make([]openapi.SpecSource, len(specsCfg.Sources))
	for i, s := range specsCfg.Sources {
		specPath := s.SpecFile
		if specsCfg.Directory != "" && !filepath.IsAbs(specPath) {
			specPath = filepath.Join(specsCfg.Directory, specPath)
		}
		sources[i] = openapi.SpecSource{
			ServiceID: s.ServiceID,
			SpecPath:  specPath,
		}
	}
	return sources
}

func buildSpecServiceIDs(sources []openapi.SpecSource) []string {
	ids := make([]string, len(sources))
	for i, s := range sources {
		ids[i] = s.ServiceID
	}
	return ids
}
