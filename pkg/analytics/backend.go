package analytics

import (
	"context"
	"time"
)

// TenantFilter holds the resolved tenant and partition scope for queries.
type TenantFilter struct {
	TenantID     string
	PartitionIDs []string
	Scoped       bool // false = skip tenant/partition filtering
}

// MetricsBackend abstracts the metrics query backend. Implementations
// translate structured MetricQuery definitions into the backend's native
// query language (PromQL, MQL, SQL, etc.).
type MetricsBackend interface {
	// QueryScalar executes a query that returns a single numeric value
	// (e.g. total count, average, sum).
	QueryScalar(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange) (float64, error)

	// QueryTimeSeries executes a range query that returns time-bucketed values.
	QueryTimeSeries(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, step time.Duration) ([]TimeSeriesPoint, error)

	// QueryGrouped executes a query grouped by a label, returning label→value pairs.
	QueryGrouped(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, groupBy string) ([]LabelValue, error)

	// QueryTopN executes a query returning the top N items by value.
	QueryTopN(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, groupBy string, limit int) ([]LabelValue, error)

	// Healthy checks that the backend is reachable.
	Healthy(ctx context.Context) error
}

// LabelValue is a label→value pair returned by grouped or top-N queries.
type LabelValue struct {
	Label string
	Value float64
}
