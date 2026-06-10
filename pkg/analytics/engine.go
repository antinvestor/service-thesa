package analytics

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/pitabwire/util"

	"github.com/antinvestor/service-thesa/model"
)

// GlobalViewCapability is the capability that allows queries without tenant
// scoping. Requests whose JWT carries no tenant claims are rejected unless
// the caller holds it; every use is audit-logged.
const GlobalViewCapability = "analytics:global:view"

// ErrTenantScopeRequired is returned when a query has no tenant scope and the
// caller lacks GlobalViewCapability. Handlers map it to HTTP 403.
var ErrTenantScopeRequired = errors.New("analytics queries require tenant scope")

// ErrMetricNotAllowed is returned when a queried metric name does not match
// the configured allowlist. Handlers map it to HTTP 400.
var ErrMetricNotAllowed = errors.New("metric not allowed")

// defaultCacheTTL is the response-cache TTL applied when no WithCacheTTL
// option is given (overridable via ANALYTICS_CACHE_TTL).
const defaultCacheTTL = 120 * time.Second

// PartitionResolver resolves the full set of partition IDs that should be
// included in analytics queries. For a user viewing a top-level partition,
// this returns the partition itself plus any child partitions the user has
// access to. Implementations may cache results.
type PartitionResolver interface {
	ResolveAccessiblePartitions(ctx context.Context, rctx *model.RequestContext) ([]string, error)
}

// DefaultPartitionResolver returns only the user's current partition.
type DefaultPartitionResolver struct{}

func (d DefaultPartitionResolver) ResolveAccessiblePartitions(_ context.Context, rctx *model.RequestContext) ([]string, error) {
	return []string{rctx.PartitionID}, nil
}

// Engine queries metrics through a pluggable MetricsBackend. All queries are
// automatically scoped to the requesting user's tenant and accessible
// partitions, validated against the metric allowlist, and served from a TTL
// response cache when possible.
type Engine struct {
	backend           MetricsBackend
	partitionResolver PartitionResolver
	allowlist         *metricAllowlist
	cache             *queryCache

	cacheTTL        time.Duration
	allowedPatterns []string
}

// EngineOption customizes an Engine.
type EngineOption func(*Engine)

// WithCacheTTL sets the response cache TTL. A zero or negative TTL disables
// the cache. Without this option the default of 120s applies.
func WithCacheTTL(ttl time.Duration) EngineOption {
	return func(e *Engine) { e.cacheTTL = ttl }
}

// WithAllowedMetrics sets the metric-name allowlist regexes. An empty list
// keeps DefaultAllowedMetricPatterns.
func WithAllowedMetrics(patterns []string) EngineOption {
	return func(e *Engine) { e.allowedPatterns = patterns }
}

// NewEngine creates an Engine backed by the given metrics backend and partition
// resolver. If resolver is nil, DefaultPartitionResolver is used. It returns
// an error when a configured allowlist pattern does not compile.
func NewEngine(backend MetricsBackend, resolver PartitionResolver, opts ...EngineOption) (*Engine, error) {
	if resolver == nil {
		resolver = DefaultPartitionResolver{}
	}
	e := &Engine{
		backend:           backend,
		partitionResolver: resolver,
		cacheTTL:          defaultCacheTTL,
	}
	for _, opt := range opts {
		opt(e)
	}

	allowlist, err := newMetricAllowlist(e.allowedPatterns)
	if err != nil {
		return nil, err
	}
	e.allowlist = allowlist

	if e.cacheTTL > 0 {
		e.cache = newQueryCache(e.cacheTTL)
	}
	return e, nil
}

// TimeRange represents a query time window.
type TimeRange struct {
	Start       time.Time `json:"start"`
	End         time.Time `json:"end"`
	Granularity string    `json:"granularity,omitempty"`
}

// Metric represents a single KPI value with optional trend.
type Metric struct {
	Key           string   `json:"key"`
	Label         string   `json:"label"`
	Value         float64  `json:"value"`
	PreviousValue *float64 `json:"previous_value,omitempty"`
	Unit          string   `json:"unit"`
	Trend         string   `json:"trend,omitempty"`
	Icon          string   `json:"icon,omitempty"`
}

// TimeSeriesPoint is a single data point.
type TimeSeriesPoint struct {
	Timestamp time.Time `json:"timestamp"`
	Value     float64   `json:"value"`
	Label     string    `json:"label,omitempty"`
}

// TimeSeries is a named series of data points.
type TimeSeries struct {
	Key    string            `json:"key"`
	Label  string            `json:"label"`
	Points []TimeSeriesPoint `json:"points"`
	Color  string            `json:"color,omitempty"`
}

// DistributionSegment is a segment in a distribution chart.
type DistributionSegment struct {
	Label string  `json:"label"`
	Value float64 `json:"value"`
	Color string  `json:"color,omitempty"`
}

// TopNItem is a ranked item.
type TopNItem struct {
	Label    string            `json:"label"`
	Value    float64           `json:"value"`
	Metadata map[string]string `json:"metadata,omitempty"`
}

// Scalar executes a query that returns a single numeric value.
func (e *Engine) Scalar(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange) (float64, error) {
	query, filter, err := e.prepare(ctx, query, partitionIDs)
	if err != nil {
		return 0, err
	}

	key := e.lookupKey("scalar", query, filter, tr, nil)
	if cached, ok := e.cacheGet(key); ok {
		if val, isFloat := cached.(float64); isFloat {
			return val, nil
		}
	}

	val, err := e.backend.QueryScalar(ctx, query, filter, tr)
	if err != nil {
		return 0, err
	}
	e.cachePut(key, val)
	return val, nil
}

// TimeSeries executes a range query that returns time-bucketed data.
func (e *Engine) TimeSeries(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange, step time.Duration) ([]TimeSeriesPoint, error) {
	query, filter, err := e.prepare(ctx, query, partitionIDs)
	if err != nil {
		return nil, err
	}

	key := e.lookupKey("timeseries", query, filter, tr, map[string]string{"step": step.String()})
	if cached, ok := e.cacheGet(key); ok {
		if points, isPoints := cached.([]TimeSeriesPoint); isPoints {
			return points, nil
		}
	}

	points, err := e.backend.QueryTimeSeries(ctx, query, filter, tr, step)
	if err != nil {
		return nil, err
	}
	e.cachePut(key, points)
	return points, nil
}

// Grouped executes a query grouped by a label, returning label-value pairs.
func (e *Engine) Grouped(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange, groupBy string) ([]DistributionSegment, error) {
	query, filter, err := e.prepare(ctx, query, partitionIDs)
	if err != nil {
		return nil, err
	}

	key := e.lookupKey("grouped", query, filter, tr, map[string]string{"group_by": groupBy})
	if cached, ok := e.cacheGet(key); ok {
		if segments, isSegments := cached.([]DistributionSegment); isSegments {
			return segments, nil
		}
	}

	items, err := e.backend.QueryGrouped(ctx, query, filter, tr, groupBy)
	if err != nil {
		return nil, err
	}
	segments := make([]DistributionSegment, len(items))
	for i, item := range items {
		segments[i] = DistributionSegment{Label: item.Label, Value: item.Value}
	}
	e.cachePut(key, segments)
	return segments, nil
}

// TopN executes a query returning the top N items by value.
func (e *Engine) TopN(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange, groupBy string, limit int) ([]TopNItem, error) {
	query, filter, err := e.prepare(ctx, query, partitionIDs)
	if err != nil {
		return nil, err
	}

	key := e.lookupKey("topn", query, filter, tr,
		map[string]string{"group_by": groupBy, "limit": fmt.Sprintf("%d", limit)})
	if cached, ok := e.cacheGet(key); ok {
		if items, isItems := cached.([]TopNItem); isItems {
			return items, nil
		}
	}

	items, err := e.backend.QueryTopN(ctx, query, filter, tr, groupBy, limit)
	if err != nil {
		return nil, err
	}
	result := make([]TopNItem, len(items))
	for i, item := range items {
		result[i] = TopNItem{Label: item.Label, Value: item.Value}
	}
	e.cachePut(key, result)
	return result, nil
}

// prepare runs the mandatory pre-query pipeline shared by all query kinds:
// metric allowlist validation, neutralization of client-supplied tenancy
// filters, and tenant scope resolution. Every backend query flows through it.
func (e *Engine) prepare(ctx context.Context, query MetricQuery, partitionIDs []string) (MetricQuery, TenantFilter, error) {
	if err := e.allowlist.validate(query); err != nil {
		return query, TenantFilter{}, err
	}

	query = sanitizeQueryFilters(query)

	filter, err := e.resolveFilter(ctx, query, partitionIDs)
	if err != nil {
		return query, TenantFilter{}, err
	}
	return query, filter, nil
}

// lookupKey builds a cache key, or returns "" when caching is disabled.
func (e *Engine) lookupKey(kind string, query MetricQuery, filter TenantFilter, tr TimeRange, extra map[string]string) string {
	if e.cache == nil {
		return ""
	}
	return buildCacheKey(kind, query, filter, tr, extra)
}

func (e *Engine) cacheGet(key string) (any, bool) {
	if e.cache == nil || key == "" {
		return nil, false
	}
	return e.cache.get(key)
}

func (e *Engine) cachePut(key string, value any) {
	if e.cache == nil || key == "" {
		return
	}
	e.cache.put(key, value)
}

// sanitizeQueryFilters returns a copy of the query with client-supplied
// filters on the reserved tenancy labels (tenant_id / partition_id, in any
// dot or underscore spelling) removed, recursively through ratio queries.
// The authoritative tenancy matchers are always injected from the resolved
// TenantFilter, so client filters can never override them.
func sanitizeQueryFilters(query MetricQuery) MetricQuery {
	if len(query.Filters) > 0 {
		cleaned := make(map[string]string, len(query.Filters))
		for k, v := range query.Filters {
			if isReservedScopeLabel(sanitizeLabelName(k)) {
				continue
			}
			cleaned[k] = v
		}
		query.Filters = cleaned
	}
	if query.Numerator != nil {
		num := sanitizeQueryFilters(*query.Numerator)
		query.Numerator = &num
	}
	if query.Denominator != nil {
		den := sanitizeQueryFilters(*query.Denominator)
		query.Denominator = &den
	}
	return query
}

// Healthy checks that the metrics backend is reachable.
func (e *Engine) Healthy(ctx context.Context) error {
	checkCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	return e.backend.Healthy(checkCtx)
}

// resolveFilter builds a TenantFilter from the request context and the
// caller-supplied partition IDs.
//
// Tenant scoping is mandatory: when the request context carries no tenant
// claims the query is rejected with ErrTenantScopeRequired, unless the caller
// holds GlobalViewCapability — in which case an unscoped query is allowed and
// an audit log line records it.
//
// Partition resolution for scoped queries:
//   - Empty partitionIDs: use the current partition from request context.
//   - ["*"]: resolve all accessible partitions via PartitionResolver.
//   - Explicit list: validate each is in the accessible set.
func (e *Engine) resolveFilter(ctx context.Context, query MetricQuery, partitionIDs []string) (TenantFilter, error) {
	rctx := model.RequestContextFrom(ctx)

	if rctx == nil || rctx.TenantID == "" {
		caps := model.CapabilitiesFrom(ctx)
		if !caps.Has(GlobalViewCapability) {
			return TenantFilter{}, ErrTenantScopeRequired
		}

		subjectID := ""
		if rctx != nil {
			subjectID = rctx.SubjectID
		}
		// Audit trail: unscoped queries see cross-tenant data and must be
		// attributable.
		util.Log(ctx).Warn("analytics: unscoped global query authorized",
			"capability", GlobalViewCapability,
			"subject_id", subjectID,
			"metric", query.Metric,
		)
		return TenantFilter{Scoped: false}, nil
	}

	accessible, err := e.partitionResolver.ResolveAccessiblePartitions(ctx, rctx)
	if err != nil {
		return TenantFilter{}, fmt.Errorf("resolve partitions: %w", err)
	}

	var resolved []string

	switch {
	case len(partitionIDs) == 0:
		// Default: use current partition from context.
		resolved = []string{rctx.PartitionID}

	case len(partitionIDs) == 1 && partitionIDs[0] == "*":
		// Wildcard: use all accessible partitions.
		resolved = accessible

	default:
		// Explicit list: validate each partition is accessible.
		accessSet := make(map[string]bool, len(accessible))
		for _, id := range accessible {
			accessSet[id] = true
		}
		for _, id := range partitionIDs {
			if !accessSet[id] {
				return TenantFilter{}, fmt.Errorf("partition %q is not accessible", id)
			}
		}
		resolved = partitionIDs
	}

	// Drop empty partition IDs (e.g. tokens without a partition claim): the
	// partition matcher is only added when partitions are actually present.
	nonEmpty := resolved[:0]
	for _, id := range resolved {
		if id != "" {
			nonEmpty = append(nonEmpty, id)
		}
	}

	return TenantFilter{
		TenantID:     rctx.TenantID,
		PartitionIDs: nonEmpty,
		Scoped:       true,
	}, nil
}

// isValidationError checks if an error is a user-input validation error.
func isValidationError(err error) bool {
	if errors.Is(err, ErrMetricNotAllowed) {
		return true
	}
	msg := err.Error()
	return strings.HasPrefix(msg, "invalid group_by") ||
		strings.HasPrefix(msg, "invalid granularity")
}

// isForbiddenError checks if an error is a tenancy or partition access denial.
func isForbiddenError(err error) bool {
	if errors.Is(err, ErrTenantScopeRequired) {
		return true
	}
	return strings.HasSuffix(err.Error(), "is not accessible")
}
