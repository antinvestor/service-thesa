package analytics

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"github.com/lib/pq"

	"github.com/antinvestor/service-thesa/model"
)

// PartitionResolver resolves the full set of partition IDs that should be
// included in analytics queries. For a user viewing a top-level partition,
// this returns the partition itself plus any child partitions the user has
// access to. Implementations may cache results.
type PartitionResolver interface {
	// ResolveAccessiblePartitions returns partition IDs the user can see
	// analytics for, given their current request context. The result always
	// includes rctx.PartitionID and may include accessible child partitions.
	ResolveAccessiblePartitions(ctx context.Context, rctx *model.RequestContext) ([]string, error)
}

// DefaultPartitionResolver returns only the user's current partition — no
// hierarchy expansion. Use this when the tenancy service is not available
// or hierarchy traversal is not needed.
type DefaultPartitionResolver struct{}

func (d DefaultPartitionResolver) ResolveAccessiblePartitions(_ context.Context, rctx *model.RequestContext) ([]string, error) {
	return []string{rctx.PartitionID}, nil
}

// Engine queries the analytics database using registry-defined, parameterized
// SQL. All queries are automatically scoped to the requesting user's tenant
// and accessible partitions, resolved transparently from the request context.
type Engine struct {
	db                *sql.DB
	registry          *Registry
	partitionResolver PartitionResolver
}

// NewEngine creates an Engine backed by the given database, registry, and
// partition resolver. If resolver is nil, DefaultPartitionResolver is used.
func NewEngine(db *sql.DB, registry *Registry, resolver PartitionResolver) *Engine {
	if resolver == nil {
		resolver = DefaultPartitionResolver{}
	}
	return &Engine{db: db, registry: registry, partitionResolver: resolver}
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

// QueryMetrics returns all KPI values for a service, with previous-period
// trend comparison. Tenant and partition scoping is extracted from ctx.
func (e *Engine) QueryMetrics(ctx context.Context, serviceID string, tr TimeRange) ([]Metric, error) {
	sa, ok := e.registry.Get(serviceID)
	if !ok {
		return nil, fmt.Errorf("no analytics registered for service %q", serviceID)
	}

	scope, err := e.scopeFromContext(ctx)
	if err != nil {
		return nil, err
	}

	duration := tr.End.Sub(tr.Start)
	prevRange := TimeRange{
		Start: tr.Start.Add(-duration),
		End:   tr.Start,
	}

	metrics := make([]Metric, 0, len(sa.Metrics))
	for _, md := range sa.Metrics {
		m := Metric{Key: md.Key, Label: md.Label, Unit: md.Unit, Icon: md.Icon}

		args := buildBaseArgs(tr, scope, sa.TenantScoped)
		var val float64
		if err := e.db.QueryRowContext(ctx, md.SQL, args...).Scan(&val); err != nil && err != sql.ErrNoRows {
			return nil, fmt.Errorf("metric %s: %w", md.Key, err)
		}
		m.Value = val

		prevArgs := buildBaseArgs(prevRange, scope, sa.TenantScoped)
		var prevVal float64
		if err := e.db.QueryRowContext(ctx, md.SQL, prevArgs...).Scan(&prevVal); err == nil {
			m.PreviousValue = &prevVal
			switch {
			case val > prevVal:
				m.Trend = "up"
			case val < prevVal:
				m.Trend = "down"
			default:
				m.Trend = "flat"
			}
		}

		metrics = append(metrics, m)
	}

	return metrics, nil
}

// QueryTimeSeries returns time-bucketed data for a named metric.
func (e *Engine) QueryTimeSeries(ctx context.Context, serviceID, metric string, tr TimeRange) ([]TimeSeries, error) {
	sa, ok := e.registry.Get(serviceID)
	if !ok {
		return nil, fmt.Errorf("no analytics registered for service %q", serviceID)
	}

	scope, err := e.scopeFromContext(ctx)
	if err != nil {
		return nil, err
	}

	var def *TimeSeriesDefinition
	for i := range sa.TimeSeries {
		if sa.TimeSeries[i].Key == metric {
			def = &sa.TimeSeries[i]
			break
		}
	}
	if def == nil {
		return nil, fmt.Errorf("no time series %q for service %q", metric, serviceID)
	}

	granularity, err := ValidateGranularity(tr.Granularity)
	if err != nil {
		return nil, err
	}

	query := strings.ReplaceAll(def.SQL, "{{granularity}}", granularity)
	args := buildBaseArgs(tr, scope, sa.TenantScoped)

	rows, err := e.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("time series %s: %w", metric, err)
	}
	defer func() { _ = rows.Close() }()

	var points []TimeSeriesPoint
	for rows.Next() {
		var p TimeSeriesPoint
		if err := rows.Scan(&p.Timestamp, &p.Value); err != nil {
			return nil, fmt.Errorf("scan time series: %w", err)
		}
		points = append(points, p)
	}

	return []TimeSeries{{
		Key:    def.Key,
		Label:  def.Label,
		Points: points,
		Color:  def.Color,
	}}, rows.Err()
}

// QueryDistribution returns grouped aggregation data. The groupBy value is
// validated against the definition's AllowedGroupBy allowlist.
func (e *Engine) QueryDistribution(ctx context.Context, serviceID, metric, groupBy string, tr TimeRange) ([]DistributionSegment, error) {
	sa, ok := e.registry.Get(serviceID)
	if !ok {
		return nil, fmt.Errorf("no analytics registered for service %q", serviceID)
	}

	scope, err := e.scopeFromContext(ctx)
	if err != nil {
		return nil, err
	}

	var def *DistributionDefinition
	for i := range sa.Distributions {
		if sa.Distributions[i].Key == metric {
			def = &sa.Distributions[i]
			break
		}
	}
	if def == nil {
		return nil, fmt.Errorf("no distribution %q for service %q", metric, serviceID)
	}

	if err := ValidateGroupBy(def.AllowedGroupBy, groupBy); err != nil {
		return nil, err
	}

	query := strings.ReplaceAll(def.SQL, "{{group_by}}", pq.QuoteIdentifier(groupBy))
	args := buildBaseArgs(tr, scope, sa.TenantScoped)

	rows, err := e.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("distribution %s: %w", metric, err)
	}
	defer func() { _ = rows.Close() }()

	var segments []DistributionSegment
	for rows.Next() {
		var s DistributionSegment
		if err := rows.Scan(&s.Label, &s.Value); err != nil {
			return nil, fmt.Errorf("scan distribution: %w", err)
		}
		segments = append(segments, s)
	}

	return segments, rows.Err()
}

// QueryTopN returns ranked items. The limit is capped by the definition's MaxLimit.
func (e *Engine) QueryTopN(ctx context.Context, serviceID, metric string, limit int, tr TimeRange) ([]TopNItem, error) {
	sa, ok := e.registry.Get(serviceID)
	if !ok {
		return nil, fmt.Errorf("no analytics registered for service %q", serviceID)
	}

	scope, err := e.scopeFromContext(ctx)
	if err != nil {
		return nil, err
	}

	var def *TopNDefinition
	for i := range sa.TopN {
		if sa.TopN[i].Key == metric {
			def = &sa.TopN[i]
			break
		}
	}
	if def == nil {
		return nil, fmt.Errorf("no top-N %q for service %q", metric, serviceID)
	}

	maxLimit := def.MaxLimit
	if maxLimit <= 0 {
		maxLimit = 100
	}
	if limit <= 0 || limit > maxLimit {
		limit = min(10, maxLimit)
	}

	args := buildBaseArgs(tr, scope, sa.TenantScoped)
	args = append(args, limit)

	rows, err := e.db.QueryContext(ctx, def.SQL, args...)
	if err != nil {
		return nil, fmt.Errorf("top-N %s: %w", metric, err)
	}
	defer func() { _ = rows.Close() }()

	var items []TopNItem
	for rows.Next() {
		var item TopNItem
		if err := rows.Scan(&item.Label, &item.Value); err != nil {
			return nil, fmt.Errorf("scan top-N: %w", err)
		}
		items = append(items, item)
	}

	return items, rows.Err()
}

// Healthy checks that the analytics database connection is alive.
func (e *Engine) Healthy(ctx context.Context) error {
	checkCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	return e.db.PingContext(checkCtx)
}

// tenantScope holds the resolved tenant and partition scope for a query.
// PartitionIDs contains the user's current partition plus any accessible
// child partitions — passed to SQL as a PostgreSQL array via ANY($4).
type tenantScope struct {
	TenantID     string
	PartitionIDs []string
}

// scopeFromContext extracts the tenant ID from the request context and
// resolves accessible partition IDs (current + children) via the
// PartitionResolver. This is the single place where tenancy data flows
// into the analytics engine — callers never pass scope explicitly.
func (e *Engine) scopeFromContext(ctx context.Context) (tenantScope, error) {
	rctx := model.RequestContextFrom(ctx)
	if rctx == nil {
		return tenantScope{}, fmt.Errorf("missing request context")
	}

	partitionIDs, err := e.partitionResolver.ResolveAccessiblePartitions(ctx, rctx)
	if err != nil {
		return tenantScope{}, fmt.Errorf("resolve partitions: %w", err)
	}

	return tenantScope{
		TenantID:     rctx.TenantID,
		PartitionIDs: partitionIDs,
	}, nil
}

// buildBaseArgs returns the standard query arguments: ($1=start, $2=end) and
// optionally ($3=tenant_id, $4=partition_ids[]) when tenant-scoped.
// The partition IDs are passed as a PostgreSQL text array for use with ANY($4).
func buildBaseArgs(tr TimeRange, scope tenantScope, tenantScoped bool) []any {
	args := []any{tr.Start.UTC(), tr.End.UTC()}
	if tenantScoped {
		args = append(args, scope.TenantID, pq.Array(scope.PartitionIDs))
	}
	return args
}
