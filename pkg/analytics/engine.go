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

// Engine queries metrics through a pluggable MetricsBackend. All queries are
// automatically scoped to the requesting user's tenant and accessible partitions.
type Engine struct {
	backend           MetricsBackend
	partitionResolver PartitionResolver
}

// NewEngine creates an Engine backed by the given metrics backend and partition
// resolver. If resolver is nil, DefaultPartitionResolver is used.
func NewEngine(backend MetricsBackend, resolver PartitionResolver) *Engine {
	if resolver == nil {
		resolver = DefaultPartitionResolver{}
	}
	return &Engine{backend: backend, partitionResolver: resolver}
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
	filter, err := e.resolveFilter(ctx, partitionIDs)
	if err != nil {
		return 0, err
	}
	return e.backend.QueryScalar(ctx, query, filter, tr)
}

// TimeSeries executes a range query that returns time-bucketed data.
func (e *Engine) TimeSeries(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange, step time.Duration) ([]TimeSeriesPoint, error) {
	filter, err := e.resolveFilter(ctx, partitionIDs)
	if err != nil {
		return nil, err
	}
	return e.backend.QueryTimeSeries(ctx, query, filter, tr, step)
}

// Grouped executes a query grouped by a label, returning label-value pairs.
func (e *Engine) Grouped(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange, groupBy string) ([]DistributionSegment, error) {
	filter, err := e.resolveFilter(ctx, partitionIDs)
	if err != nil {
		return nil, err
	}
	items, err := e.backend.QueryGrouped(ctx, query, filter, tr, groupBy)
	if err != nil {
		return nil, err
	}
	segments := make([]DistributionSegment, len(items))
	for i, item := range items {
		segments[i] = DistributionSegment{Label: item.Label, Value: item.Value}
	}
	return segments, nil
}

// TopN executes a query returning the top N items by value.
func (e *Engine) TopN(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange, groupBy string, limit int) ([]TopNItem, error) {
	filter, err := e.resolveFilter(ctx, partitionIDs)
	if err != nil {
		return nil, err
	}
	items, err := e.backend.QueryTopN(ctx, query, filter, tr, groupBy, limit)
	if err != nil {
		return nil, err
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

// resolveFilter builds a TenantFilter from the request context and the
// caller-supplied partition IDs.
//   - Empty partitionIDs: use the current partition from request context.
//   - ["*"]: resolve all accessible partitions via PartitionResolver.
//   - Explicit list: validate each is in the accessible set.
func (e *Engine) resolveFilter(ctx context.Context, partitionIDs []string) (TenantFilter, error) {
	rctx := model.RequestContextFrom(ctx)
	if rctx == nil {
		return TenantFilter{}, fmt.Errorf("missing request context")
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

	return TenantFilter{
		TenantID:     rctx.TenantID,
		PartitionIDs: resolved,
		Scoped:       true,
	}, nil
}

// isValidationError checks if an error is a user-input validation error.
func isValidationError(err error) bool {
	msg := err.Error()
	return strings.HasPrefix(msg, "invalid group_by") ||
		strings.HasPrefix(msg, "invalid granularity")
}

// isForbiddenError checks if an error is a partition access denial.
func isForbiddenError(err error) bool {
	return strings.HasSuffix(err.Error(), "is not accessible")
}
