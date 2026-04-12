// Package main is the entry point for the Thesa BFF server.
// It wires all dependencies together and starts the HTTP server using Frame.
package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"net/http"
	"path/filepath"

	_ "github.com/lib/pq"
	"github.com/pitabwire/frame"
	"github.com/pitabwire/frame/security/interceptors/httptor"
	frameversion "github.com/pitabwire/frame/version"
	"github.com/pitabwire/util"

	"github.com/antinvestor/service-thesa/internal/analytics"
	"github.com/antinvestor/service-thesa/internal/capability"
	"github.com/antinvestor/service-thesa/internal/command"
	"github.com/antinvestor/service-thesa/internal/config"
	"github.com/antinvestor/service-thesa/internal/definition"
	"github.com/antinvestor/service-thesa/internal/invoker"
	"github.com/antinvestor/service-thesa/internal/metadata"
	"github.com/antinvestor/service-thesa/internal/openapi"
	"github.com/antinvestor/service-thesa/internal/search"
	"github.com/antinvestor/service-thesa/internal/transport"
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
	// Service name defaults to "service-thesa" but can be overridden
	// via SERVICE_NAME env var (standard for all antinvestor services).
	serviceName := cfg.ServiceName
	if serviceName == "" {
		serviceName = "service-thesa"
	}
	ctx, svc := frame.NewServiceWithContext(ctx,
		frame.WithName(serviceName),
		frame.WithConfig(cfg),
	)

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

	// Analytics engine — connects to the analytics TimescaleDB when enabled.
	var analyticsEngine *analytics.Engine
	if cfg.Analytics.Enabled && cfg.Analytics.DSN != "" {
		analyticsDB, err := sql.Open("postgres", cfg.Analytics.DSN)
		if err != nil {
			log.WithError(err).Fatal("analytics database connection failed")
		}
		defer func() { _ = analyticsDB.Close() }()

		analyticsDB.SetMaxOpenConns(10)
		analyticsDB.SetMaxIdleConns(5)

		analyticsReg := analytics.NewRegistry()
		if err := analytics.RegisterDefaultServices(analyticsReg); err != nil {
			log.WithError(err).Fatal("analytics service registration failed")
		}
		analyticsEngine = analytics.NewEngine(analyticsDB, analyticsReg, nil)

		if err := analyticsEngine.Healthy(ctx); err != nil {
			log.WithError(err).Warn("analytics database not reachable at startup")
		}

		log.Info("analytics engine enabled",
			"services", len(analyticsReg.Services()),
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

	if analyticsEngine != nil {
		svc.AddHealthCheck(frame.CheckerFunc(func() error {
			return analyticsEngine.Healthy(ctx)
		}))
	}

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

	log = util.Log(ctx)
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
