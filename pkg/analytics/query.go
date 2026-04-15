package analytics

import (
	"fmt"
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
	AggSum           Aggregation = "sum"            // sum all matching series
	AggAvg           Aggregation = "avg"            // average across matching series
	AggCount         Aggregation = "count"          // count of matching series
	AggCountDistinct Aggregation = "count_distinct" // count unique values of a label
	AggGauge         Aggregation = "gauge"          // current gauge value (no rate/increase)
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

// ValidateGroupBy checks that a group_by value is in the allowed list.
func ValidateGroupBy(allowed []string, value string) error {
	for _, a := range allowed {
		if a == value {
			return nil
		}
	}
	return fmt.Errorf("invalid group_by %q; allowed: %v", value, allowed)
}

// TimeRangeRequest represents the time range portion of an analytics API request.
type TimeRangeRequest struct {
	Start string `json:"start"` // RFC3339 timestamp
	End   string `json:"end"`   // RFC3339 timestamp
}

// AnalyticsRequest is the JSON body for POST analytics endpoints.
type AnalyticsRequest struct {
	Metric       string            `json:"metric"`
	Aggregation  Aggregation       `json:"aggregation"`
	Filters      map[string]string `json:"filters,omitempty"`
	GroupBy      string            `json:"group_by,omitempty"`
	PartitionIDs []string          `json:"partition_ids,omitempty"`
	Numerator    *MetricQuery      `json:"numerator,omitempty"`
	Denominator  *MetricQuery      `json:"denominator,omitempty"`
	Limit        int               `json:"limit,omitempty"`
	TimeRange    TimeRangeRequest  `json:"time_range"`
	Step         string            `json:"step,omitempty"` // granularity for timeseries (e.g. "hour", "day")
}

// ToMetricQuery converts an AnalyticsRequest into a MetricQuery.
// If Numerator and Denominator are set, a ratio query is returned.
func (ar *AnalyticsRequest) ToMetricQuery() MetricQuery {
	if ar.Numerator != nil && ar.Denominator != nil {
		return MetricQuery{
			Numerator:   ar.Numerator,
			Denominator: ar.Denominator,
			Filters:     ar.Filters,
			GroupBy:     ar.GroupBy,
		}
	}
	return MetricQuery{
		Metric:      ar.Metric,
		Aggregation: ar.Aggregation,
		Filters:     ar.Filters,
		GroupBy:     ar.GroupBy,
	}
}
