package analytics

import (
	"fmt"
	"sync"
	"time"
)

// allowedGranularities maps user-facing granularity names to step durations.
var allowedGranularities = map[string]time.Duration{
	"minute":  time.Minute,
	"hour":    time.Hour,
	"day":     24 * time.Hour,
	"week":    7 * 24 * time.Hour,
	"month":   30 * 24 * time.Hour,
	"quarter": 90 * 24 * time.Hour,
	"year":    365 * 24 * time.Hour,
}

// ValidateGranularity returns the step duration for a granularity name,
// or an error if the value is not in the allowlist.
func ValidateGranularity(g string) (time.Duration, error) {
	if g == "" {
		return 24 * time.Hour, nil
	}
	d, ok := allowedGranularities[g]
	if !ok {
		return 0, fmt.Errorf("invalid granularity %q", g)
	}
	return d, nil
}

// Aggregation describes how a metric should be aggregated.
type Aggregation string

const (
	AggSum          Aggregation = "sum"           // sum all matching series
	AggAvg          Aggregation = "avg"           // average across matching series
	AggCount        Aggregation = "count"         // count of matching series
	AggCountDistinct Aggregation = "count_distinct" // count unique values of a label
	AggGauge        Aggregation = "gauge"         // current gauge value (no rate/increase)
)

// MetricQuery describes a metric query in backend-agnostic terms using
// OTel metric names and attribute names.
type MetricQuery struct {
	// Metric is the OTel metric name (e.g. "payment_transactions_total").
	Metric string

	// Aggregation is how to aggregate the metric values.
	Aggregation Aggregation

	// Filters are additional label/attribute matchers applied alongside the
	// tenant and partition filters (e.g. {"status": "success"}).
	Filters map[string]string

	// GroupBy is the attribute to group results by (for distributions).
	// Left empty for scalar queries.
	GroupBy string

	// Numerator and Denominator support ratio metrics (e.g., success rate).
	// When set, the result is Numerator / Denominator * 100.
	Numerator   *MetricQuery
	Denominator *MetricQuery

	// DurationMetric + DurationCountMetric support average-duration metrics.
	// Result is DurationMetric / DurationCountMetric (histogram sum/count pattern).
	DurationMetric      string
	DurationCountMetric string

	// Multiplier scales the result (e.g., 1000 to convert seconds to ms).
	Multiplier float64
}

// IsRatio returns true if this query computes a ratio (Numerator/Denominator).
func (q MetricQuery) IsRatio() bool {
	return q.Numerator != nil && q.Denominator != nil
}

// IsDuration returns true if this query computes an average duration.
func (q MetricQuery) IsDuration() bool {
	return q.DurationMetric != "" && q.DurationCountMetric != ""
}

// MetricDefinition describes a single scalar KPI query.
type MetricDefinition struct {
	Key        string      // unique key referenced by the frontend
	Label      string      // human-readable label
	Unit       string      // count, currency, percent, bytes, duration
	Icon       string      // Material icon name hint
	Permission string      // optional capability override; empty = use service ViewPermission
	Query      MetricQuery // structured query definition
}

// TimeSeriesDefinition describes a range query that produces time-bucketed data.
type TimeSeriesDefinition struct {
	Key        string
	Label      string
	Color      string // hex color hint, e.g. "#4CAF50"
	Permission string
	Query      MetricQuery
}

// DistributionDefinition describes a grouped aggregation query.
type DistributionDefinition struct {
	Key            string
	Label          string
	Permission     string
	AllowedGroupBy []string // strict allowlist for group_by substitution
	Query          MetricQuery
}

// TopNDefinition describes a ranked aggregation query.
type TopNDefinition struct {
	Key        string
	Label      string
	Permission string
	MaxLimit   int // cap for the limit parameter; 0 defaults to 100
	Query      MetricQuery
}

// ServiceAnalytics is the declarative analytics registration for a service.
type ServiceAnalytics struct {
	ServiceID      string // must match the service query parameter
	ViewPermission string // capability required to access any analytics
	TenantScoped   bool   // when true, queries include tenant_id/partition_id filters

	Metrics       []MetricDefinition
	TimeSeries    []TimeSeriesDefinition
	Distributions []DistributionDefinition
	TopN          []TopNDefinition
}

// effectivePermission returns the permission to check for a specific query.
func (sa *ServiceAnalytics) effectivePermission(queryPermission string) string {
	if queryPermission != "" {
		return queryPermission
	}
	return sa.ViewPermission
}

// Registry holds all registered service analytics definitions.
type Registry struct {
	mu       sync.RWMutex
	services map[string]*ServiceAnalytics
}

// NewRegistry creates an empty analytics registry.
func NewRegistry() *Registry {
	return &Registry{services: make(map[string]*ServiceAnalytics)}
}

// Register adds a service analytics definition.
func (r *Registry) Register(sa ServiceAnalytics) error {
	if sa.ServiceID == "" {
		return fmt.Errorf("analytics: service ID is required")
	}
	if sa.ViewPermission == "" {
		return fmt.Errorf("analytics: view permission is required for service %s", sa.ServiceID)
	}

	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.services[sa.ServiceID]; exists {
		return fmt.Errorf("analytics: service %s already registered", sa.ServiceID)
	}

	cp := sa
	r.services[sa.ServiceID] = &cp
	return nil
}

// Get returns the analytics definition for a service.
func (r *Registry) Get(serviceID string) (*ServiceAnalytics, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	sa, ok := r.services[serviceID]
	return sa, ok
}

// Services returns all registered service IDs.
func (r *Registry) Services() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	ids := make([]string, 0, len(r.services))
	for id := range r.services {
		ids = append(ids, id)
	}
	return ids
}

// AllPermissions returns every unique permission string across all services.
func (r *Registry) AllPermissions() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()

	seen := make(map[string]bool)
	for _, sa := range r.services {
		seen[sa.ViewPermission] = true
		for _, m := range sa.Metrics {
			if m.Permission != "" {
				seen[m.Permission] = true
			}
		}
		for _, ts := range sa.TimeSeries {
			if ts.Permission != "" {
				seen[ts.Permission] = true
			}
		}
		for _, d := range sa.Distributions {
			if d.Permission != "" {
				seen[d.Permission] = true
			}
		}
		for _, t := range sa.TopN {
			if t.Permission != "" {
				seen[t.Permission] = true
			}
		}
	}

	perms := make([]string, 0, len(seen))
	for p := range seen {
		perms = append(perms, p)
	}
	return perms
}

// ValidateGroupBy checks that a group_by value is in the definition's allowlist.
func ValidateGroupBy(allowed []string, value string) error {
	for _, a := range allowed {
		if a == value {
			return nil
		}
	}
	return fmt.Errorf("invalid group_by %q; allowed: %v", value, allowed)
}
