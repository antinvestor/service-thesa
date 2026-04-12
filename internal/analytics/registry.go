package analytics

import (
	"fmt"
	"sync"
)

// allowedGranularities maps user-facing granularity names to PostgreSQL interval
// strings. Only values in this map are substituted into SQL — anything else is
// rejected, preventing injection via the granularity parameter.
var allowedGranularities = map[string]string{
	"minute":  "minute",
	"hour":    "hour",
	"day":     "day",
	"week":    "week",
	"month":   "month",
	"quarter": "quarter",
	"year":    "year",
}

// ValidateGranularity returns the safe SQL interval string for a granularity
// name, or an error if the value is not in the allowlist.
func ValidateGranularity(g string) (string, error) {
	if g == "" {
		return "day", nil
	}
	safe, ok := allowedGranularities[g]
	if !ok {
		return "", fmt.Errorf("invalid granularity %q", g)
	}
	return safe, nil
}

// MetricDefinition describes a single scalar KPI query.
//
// SQL convention: $1 = start time, $2 = end time, $3 = tenant_id, $4 = partition_ids (text array, used with ANY).
type MetricDefinition struct {
	Key        string // unique key referenced by the frontend
	Label      string // human-readable label
	Unit       string // count, currency, percent, bytes, duration
	Icon       string // Material icon name hint
	Permission string // optional capability override; empty = use service ViewPermission
	SQL        string // parameterized query returning a single numeric value
}

// TimeSeriesDefinition describes a time-bucketed query.
//
// SQL convention: $1 = start, $2 = end, $3 = tenant_id, $4 = partition_ids (text array, used with ANY).
// Use {{granularity}} for the date_trunc interval — substituted from allowlist.
type TimeSeriesDefinition struct {
	Key        string
	Label      string
	Color      string // hex color hint, e.g. "#4CAF50"
	Permission string
	SQL        string
}

// DistributionDefinition describes a grouped aggregation query.
//
// SQL convention: $1 = start, $2 = end, $3 = tenant_id, $4 = partition_ids (text array, used with ANY).
// Use {{group_by}} for the grouping column — substituted from AllowedGroupBy only.
type DistributionDefinition struct {
	Key            string
	Label          string
	Permission     string
	AllowedGroupBy []string // strict allowlist for group_by substitution
	SQL            string
}

// TopNDefinition describes a ranked aggregation query.
//
// SQL convention: $1 = start, $2 = end, $3 = tenant_id, $4 = partition_ids (text array, used with ANY), $5 = limit.
type TopNDefinition struct {
	Key        string
	Label      string
	Permission string
	MaxLimit   int // cap for the limit parameter; 0 defaults to 100
	SQL        string
}

// ServiceAnalytics is the declarative analytics registration for a service.
// Services register one of these at startup to expose their analytics through
// the generic API.
type ServiceAnalytics struct {
	ServiceID      string // must match the service query parameter
	ViewPermission string // capability required to access any analytics for this service
	TenantScoped   bool   // when true (default), all queries receive tenant_id as $3 and partition_ids[] as $4

	Metrics       []MetricDefinition
	TimeSeries    []TimeSeriesDefinition
	Distributions []DistributionDefinition
	TopN          []TopNDefinition
}

// effectivePermission returns the permission to check for a specific query.
// If the query has its own Permission set, that is used; otherwise the
// service-level ViewPermission applies.
func (sa *ServiceAnalytics) effectivePermission(queryPermission string) string {
	if queryPermission != "" {
		return queryPermission
	}
	return sa.ViewPermission
}

// Registry holds all registered service analytics definitions. It is safe for
// concurrent use after initial registration is complete.
type Registry struct {
	mu       sync.RWMutex
	services map[string]*ServiceAnalytics
}

// NewRegistry creates an empty analytics registry.
func NewRegistry() *Registry {
	return &Registry{services: make(map[string]*ServiceAnalytics)}
}

// Register adds a service analytics definition. Returns an error if the
// service ID is already registered or required fields are missing.
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

// Get returns the analytics definition for a service, or false if not found.
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

// AllPermissions returns every unique permission string needed across all
// registered services. This is used at startup to ensure these capabilities
// are included in the Keto batch check.
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
