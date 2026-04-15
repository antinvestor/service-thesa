package analytics

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/antinvestor/service-thesa/model"
)

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

// Engine queries metrics through a pluggable MetricsBackend using
// registry-defined structured queries. All queries are automatically scoped
// to the requesting user's tenant and accessible partitions.
type Engine struct {
	backend           MetricsBackend
	registry          *Registry
	partitionResolver PartitionResolver
}

// NewEngine creates an Engine backed by the given metrics backend, registry,
// and partition resolver. If resolver is nil, DefaultPartitionResolver is used.
func NewEngine(backend MetricsBackend, registry *Registry, resolver PartitionResolver) *Engine {
	if resolver == nil {
		resolver = DefaultPartitionResolver{}
	}
	return &Engine{backend: backend, registry: registry, partitionResolver: resolver}
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
// trend comparison.
func (e *Engine) QueryMetrics(ctx context.Context, serviceID string, tr TimeRange) ([]Metric, error) {
	sa, ok := e.registry.Get(serviceID)
	if !ok {
		return nil, fmt.Errorf("no analytics registered for service %q", serviceID)
	}

	filter, err := e.tenantFilterFromContext(ctx, sa.TenantScoped)
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

		val, err := e.backend.QueryScalar(ctx, md.Query, filter, tr)
		if err != nil {
			return nil, fmt.Errorf("metric %s: %w", md.Key, err)
		}
		m.Value = val

		prevVal, err := e.backend.QueryScalar(ctx, md.Query, filter, prevRange)
		if err == nil {
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

	filter, err := e.tenantFilterFromContext(ctx, sa.TenantScoped)
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

	step, err := ValidateGranularity(tr.Granularity)
	if err != nil {
		return nil, err
	}

	points, err := e.backend.QueryTimeSeries(ctx, def.Query, filter, tr, step)
	if err != nil {
		return nil, fmt.Errorf("time series %s: %w", metric, err)
	}

	return []TimeSeries{{
		Key:    def.Key,
		Label:  def.Label,
		Points: points,
		Color:  def.Color,
	}}, nil
}

// QueryDistribution returns grouped aggregation data.
func (e *Engine) QueryDistribution(ctx context.Context, serviceID, metric, groupBy string, tr TimeRange) ([]DistributionSegment, error) {
	sa, ok := e.registry.Get(serviceID)
	if !ok {
		return nil, fmt.Errorf("no analytics registered for service %q", serviceID)
	}

	filter, err := e.tenantFilterFromContext(ctx, sa.TenantScoped)
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

	items, err := e.backend.QueryGrouped(ctx, def.Query, filter, tr, groupBy)
	if err != nil {
		return nil, fmt.Errorf("distribution %s: %w", metric, err)
	}

	segments := make([]DistributionSegment, len(items))
	for i, item := range items {
		segments[i] = DistributionSegment{Label: item.Label, Value: item.Value}
	}
	return segments, nil
}

// QueryTopN returns ranked items.
func (e *Engine) QueryTopN(ctx context.Context, serviceID, metric string, limit int, tr TimeRange) ([]TopNItem, error) {
	sa, ok := e.registry.Get(serviceID)
	if !ok {
		return nil, fmt.Errorf("no analytics registered for service %q", serviceID)
	}

	filter, err := e.tenantFilterFromContext(ctx, sa.TenantScoped)
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

	groupBy := def.Query.GroupBy
	items, err := e.backend.QueryTopN(ctx, def.Query, filter, tr, groupBy, limit)
	if err != nil {
		return nil, fmt.Errorf("top-N %s: %w", metric, err)
	}

	result := make([]TopNItem, len(items))
	for i, item := range items {
		result[i] = TopNItem{Label: item.Label, Value: item.Value}
	}
	return result, nil
}

// Healthy checks that the metrics backend is reachable.
func (e *Engine) Healthy(ctx context.Context) error {
	checkCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	return e.backend.Healthy(checkCtx)
}

// tenantFilterFromContext extracts tenant/partition scope from the request
// context and resolves accessible partitions.
func (e *Engine) tenantFilterFromContext(ctx context.Context, tenantScoped bool) (TenantFilter, error) {
	if !tenantScoped {
		return TenantFilter{Scoped: false}, nil
	}

	rctx := model.RequestContextFrom(ctx)
	if rctx == nil {
		return TenantFilter{}, fmt.Errorf("missing request context")
	}

	partitionIDs, err := e.partitionResolver.ResolveAccessiblePartitions(ctx, rctx)
	if err != nil {
		return TenantFilter{}, fmt.Errorf("resolve partitions: %w", err)
	}

	return TenantFilter{
		TenantID:     rctx.TenantID,
		PartitionIDs: partitionIDs,
		Scoped:       true,
	}, nil
}

// isValidationError checks if an error is a user-input validation error.
func isValidationError(err error) bool {
	msg := err.Error()
	return strings.HasPrefix(msg, "invalid group_by") ||
		strings.HasPrefix(msg, "invalid granularity")
}
