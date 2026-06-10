package analytics

import (
	"fmt"
	"regexp"
)

// DefaultAllowedMetricPatterns is the default allowlist of queryable metric
// name patterns. It covers the platform service prefixes, the engine-style
// dotted namespaces, slash-namespaced device/geolocation metrics, generic
// latency/completed_calls suffixes, and the OTel semconv duration metrics.
// Override via analytics.allowed_metrics (yaml) or ANALYTICS_ALLOWED_METRICS
// (comma-separated regexes).
var DefaultAllowedMetricPatterns = []string{
	`^(loans|funding|savings|ops|identity|notifications|payments|fort|file_service|scheduler|workflow)_.+`,
	`^(engine|connector|events|formstore|queue|pipeline|scheduler)\..+`,
	`^(devices|service_geolocation)/.+`,
	`.+/(latency|completed_calls)$`,
	`^http\.server\.request\.duration$`,
	`^db\.client\.operation\.duration$`,
	`^rpc\.client\.duration$`,
	`^rpc\.server\.duration$`,
	`^gocloud\.dev/pubsub/latency$`,
}

// metricAllowlist validates metric names against a set of compiled regexes.
type metricAllowlist struct {
	patterns []*regexp.Regexp
}

// newMetricAllowlist compiles the given patterns. An empty list falls back to
// DefaultAllowedMetricPatterns.
func newMetricAllowlist(patterns []string) (*metricAllowlist, error) {
	if len(patterns) == 0 {
		patterns = DefaultAllowedMetricPatterns
	}
	compiled := make([]*regexp.Regexp, 0, len(patterns))
	for _, p := range patterns {
		re, err := regexp.Compile(p)
		if err != nil {
			return nil, fmt.Errorf("analytics: invalid allowed_metrics pattern %q: %w", p, err)
		}
		compiled = append(compiled, re)
	}
	return &metricAllowlist{patterns: compiled}, nil
}

// allows reports whether the metric name matches any allowlist pattern.
func (m *metricAllowlist) allows(name string) bool {
	for _, re := range m.patterns {
		if re.MatchString(name) {
			return true
		}
	}
	return false
}

// validate checks every metric name referenced by the query, including
// duration metrics and nested ratio numerator/denominator queries.
func (m *metricAllowlist) validate(q MetricQuery) error {
	switch {
	case q.IsRatio():
		if err := m.validate(*q.Numerator); err != nil {
			return err
		}
		return m.validate(*q.Denominator)
	case q.IsDuration():
		for _, name := range []string{q.DurationMetric, q.DurationCountMetric} {
			if !m.allows(name) {
				return fmt.Errorf("%w: %q", ErrMetricNotAllowed, name)
			}
		}
		return nil
	case q.Metric == "":
		return fmt.Errorf("%w: metric name is required", ErrMetricNotAllowed)
	case !m.allows(q.Metric):
		return fmt.Errorf("%w: %q", ErrMetricNotAllowed, q.Metric)
	}
	return nil
}
