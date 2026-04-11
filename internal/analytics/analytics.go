// Package analytics provides a generic analytics query engine.
//
// It connects to the analytics database and provides service-scoped
// metrics, time series, distribution, and top-N queries. The query
// definitions are registered per service in queries.go.
package analytics

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"
)

// AnalyticsEngine queries the analytics database for service metrics.
type AnalyticsEngine struct {
	db *sql.DB
}

// NewEngine creates a new AnalyticsEngine with the given database connection.
func NewEngine(db *sql.DB) *AnalyticsEngine {
	return &AnalyticsEngine{db: db}
}

// TimeRange represents a query time window.
type TimeRange struct {
	Start       time.Time `json:"start"`
	End         time.Time `json:"end"`
	Granularity string    `json:"granularity,omitempty"` // minute, hour, day, week, month, quarter, year
}

// Metric represents a single KPI value.
type Metric struct {
	Key           string   `json:"key"`
	Label         string   `json:"label"`
	Value         float64  `json:"value"`
	PreviousValue *float64 `json:"previous_value,omitempty"`
	Unit          string   `json:"unit"`           // count, currency, percent, bytes
	Trend         string   `json:"trend,omitempty"` // up, down, flat
	Icon          string   `json:"icon,omitempty"`
}

// TimeSeriesPoint is a single data point in a time series.
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
	Color  string            `json:"color,omitempty"` // hex color
}

// DistributionSegment is a single segment in a distribution chart.
type DistributionSegment struct {
	Label string  `json:"label"`
	Value float64 `json:"value"`
	Color string  `json:"color,omitempty"`
}

// TopNItem is a ranked item in a top-N list.
type TopNItem struct {
	Label    string            `json:"label"`
	Value    float64           `json:"value"`
	Metadata map[string]string `json:"metadata,omitempty"`
}

// QueryMetrics returns KPI values for a service within the given time range.
// It also computes the previous period values for trend calculation.
func (e *AnalyticsEngine) QueryMetrics(ctx context.Context, service string, tr TimeRange) ([]Metric, error) {
	qs, ok := ServiceQueries[service]
	if !ok {
		return nil, fmt.Errorf("no analytics queries defined for service %q", service)
	}

	// Compute previous period for comparison
	duration := tr.End.Sub(tr.Start)
	prevRange := TimeRange{
		Start: tr.Start.Add(-duration),
		End:   tr.Start,
	}

	var metrics []Metric
	for _, mq := range qs.Metrics {
		metric := Metric{
			Key:   mq.Key,
			Label: mq.Label,
			Unit:  mq.Unit,
			Icon:  mq.Icon,
		}

		// Current period value
		query := substituteTimeRange(mq.SQL, tr)
		var val float64
		if err := e.db.QueryRowContext(ctx, query).Scan(&val); err != nil && err != sql.ErrNoRows {
			return nil, fmt.Errorf("query metric %s: %w", mq.Key, err)
		}
		metric.Value = val

		// Previous period value for trend
		prevQuery := substituteTimeRange(mq.SQL, prevRange)
		var prevVal float64
		if err := e.db.QueryRowContext(ctx, prevQuery).Scan(&prevVal); err == nil {
			metric.PreviousValue = &prevVal
			switch {
			case val > prevVal:
				metric.Trend = "up"
			case val < prevVal:
				metric.Trend = "down"
			default:
				metric.Trend = "flat"
			}
		}

		metrics = append(metrics, metric)
	}

	return metrics, nil
}

// QueryTimeSeries returns time-bucketed data for a specific metric.
func (e *AnalyticsEngine) QueryTimeSeries(ctx context.Context, service, metric string, tr TimeRange) ([]TimeSeries, error) {
	qs, ok := ServiceQueries[service]
	if !ok {
		return nil, fmt.Errorf("no analytics queries defined for service %q", service)
	}

	var tsq *TimeSeriesQuery
	for i := range qs.TimeSeries {
		if qs.TimeSeries[i].Key == metric {
			tsq = &qs.TimeSeries[i]
			break
		}
	}
	if tsq == nil {
		return nil, fmt.Errorf("no time series query %q for service %q", metric, service)
	}

	query := substituteTimeRange(tsq.SQL, tr)
	query = substituteGranularity(query, tr.Granularity)

	rows, err := e.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query time series %s: %w", metric, err)
	}
	defer rows.Close()

	var points []TimeSeriesPoint
	for rows.Next() {
		var p TimeSeriesPoint
		if err := rows.Scan(&p.Timestamp, &p.Value); err != nil {
			return nil, fmt.Errorf("scan time series row: %w", err)
		}
		points = append(points, p)
	}

	return []TimeSeries{{
		Key:    tsq.Key,
		Label:  tsq.Label,
		Points: points,
	}}, rows.Err()
}

// QueryDistribution returns grouped counts for a metric.
func (e *AnalyticsEngine) QueryDistribution(ctx context.Context, service, metric, groupBy string, tr TimeRange) ([]DistributionSegment, error) {
	qs, ok := ServiceQueries[service]
	if !ok {
		return nil, fmt.Errorf("no analytics queries defined for service %q", service)
	}

	var dq *DistributionQuery
	for i := range qs.Distributions {
		if qs.Distributions[i].Key == metric {
			dq = &qs.Distributions[i]
			break
		}
	}
	if dq == nil {
		return nil, fmt.Errorf("no distribution query %q for service %q", metric, service)
	}

	query := substituteTimeRange(dq.SQL, tr)
	query = strings.ReplaceAll(query, "{{group_by}}", groupBy)

	rows, err := e.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query distribution %s: %w", metric, err)
	}
	defer rows.Close()

	var segments []DistributionSegment
	for rows.Next() {
		var s DistributionSegment
		if err := rows.Scan(&s.Label, &s.Value); err != nil {
			return nil, fmt.Errorf("scan distribution row: %w", err)
		}
		segments = append(segments, s)
	}

	return segments, rows.Err()
}

// QueryTopN returns the top-N items for a metric.
func (e *AnalyticsEngine) QueryTopN(ctx context.Context, service, metric string, limit int, tr TimeRange) ([]TopNItem, error) {
	qs, ok := ServiceQueries[service]
	if !ok {
		return nil, fmt.Errorf("no analytics queries defined for service %q", service)
	}

	var tq *TopNQuery
	for i := range qs.TopN {
		if qs.TopN[i].Key == metric {
			tq = &qs.TopN[i]
			break
		}
	}
	if tq == nil {
		return nil, fmt.Errorf("no top-N query %q for service %q", metric, service)
	}

	query := substituteTimeRange(tq.SQL, tr)
	query = strings.ReplaceAll(query, "{{limit}}", fmt.Sprintf("%d", limit))

	rows, err := e.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query top-N %s: %w", metric, err)
	}
	defer rows.Close()

	var items []TopNItem
	for rows.Next() {
		var item TopNItem
		if err := rows.Scan(&item.Label, &item.Value); err != nil {
			return nil, fmt.Errorf("scan top-N row: %w", err)
		}
		items = append(items, item)
	}

	return items, rows.Err()
}

// substituteTimeRange replaces {{start}} and {{end}} placeholders in SQL.
func substituteTimeRange(sql string, tr TimeRange) string {
	s := strings.ReplaceAll(sql, "{{start}}", tr.Start.UTC().Format(time.RFC3339))
	return strings.ReplaceAll(s, "{{end}}", tr.End.UTC().Format(time.RFC3339))
}

// substituteGranularity replaces {{granularity}} with a SQL-compatible interval.
func substituteGranularity(sql, granularity string) string {
	interval := granularity
	if interval == "" {
		interval = "day"
	}
	return strings.ReplaceAll(sql, "{{granularity}}", interval)
}
