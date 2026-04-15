package analytics

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// PrometheusBackend implements MetricsBackend by translating structured
// MetricQuery definitions into PromQL and querying a Prometheus-compatible
// HTTP API (Prometheus, Mimir, Thanos, VictoriaMetrics, etc.).
type PrometheusBackend struct {
	baseURL    string
	httpClient *http.Client
}

var _ MetricsBackend = (*PrometheusBackend)(nil)

// NewPrometheusBackend creates a backend targeting the given base URL.
func NewPrometheusBackend(baseURL string, client *http.Client) *PrometheusBackend {
	if client == nil {
		client = &http.Client{Timeout: 30 * time.Second}
	}
	return &PrometheusBackend{baseURL: baseURL, httpClient: client}
}

func (b *PrometheusBackend) QueryScalar(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange) (float64, error) {
	promql := b.buildScalarPromQL(query, filter, tr.End.Sub(tr.Start))

	results, err := b.instantQuery(ctx, promql, tr.End)
	if err != nil {
		return 0, err
	}
	if len(results) == 0 {
		return 0, nil
	}
	return results[0].Value.Float64()
}

func (b *PrometheusBackend) QueryTimeSeries(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, step time.Duration) ([]TimeSeriesPoint, error) {
	promql := b.buildRatePromQL(query, filter, step)

	results, err := b.rangeQuery(ctx, promql, tr.Start, tr.End, step)
	if err != nil {
		return nil, err
	}

	var points []TimeSeriesPoint
	for _, r := range results {
		for _, sample := range r.Values {
			ts, _ := sample.Time()
			val, _ := sample.Float64()
			points = append(points, TimeSeriesPoint{Timestamp: ts, Value: val})
		}
	}
	return points, nil
}

func (b *PrometheusBackend) QueryGrouped(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, groupBy string) ([]LabelValue, error) {
	q := query
	q.GroupBy = groupBy
	promql := b.buildScalarPromQL(q, filter, tr.End.Sub(tr.Start))

	results, err := b.instantQuery(ctx, promql, tr.End)
	if err != nil {
		return nil, err
	}

	items := make([]LabelValue, 0, len(results))
	for _, r := range results {
		val, _ := r.Value.Float64()
		label := r.Metric[groupBy]
		if label == "" {
			label = "unknown"
		}
		items = append(items, LabelValue{Label: label, Value: val})
	}
	return items, nil
}

func (b *PrometheusBackend) QueryTopN(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, groupBy string, limit int) ([]LabelValue, error) {
	q := query
	q.GroupBy = groupBy
	inner := b.buildScalarPromQL(q, filter, tr.End.Sub(tr.Start))
	promql := fmt.Sprintf("topk(%d, %s)", limit, inner)

	results, err := b.instantQuery(ctx, promql, tr.End)
	if err != nil {
		return nil, err
	}

	items := make([]LabelValue, 0, len(results))
	for _, r := range results {
		val, _ := r.Value.Float64()
		label := r.Metric[groupBy]
		if label == "" {
			label = firstNonEmptyLabel(r.Metric)
		}
		items = append(items, LabelValue{Label: label, Value: val})
	}
	return items, nil
}

func (b *PrometheusBackend) Healthy(ctx context.Context) error {
	reqURL := b.baseURL + "/api/v1/status/buildinfo"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return err
	}
	resp, err := b.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("metrics backend health check: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("metrics backend returned status %d", resp.StatusCode)
	}
	return nil
}

// --- PromQL generation ---

// buildScalarPromQL constructs a PromQL instant query for a structured MetricQuery.
func (b *PrometheusBackend) buildScalarPromQL(query MetricQuery, filter TenantFilter, dur time.Duration) string {
	rangeDur := formatDuration(dur)

	if query.IsRatio() {
		num := b.buildScalarPromQL(*query.Numerator, filter, dur)
		den := b.buildScalarPromQL(*query.Denominator, filter, dur)
		return fmt.Sprintf("(%s) / (%s) * 100", num, den)
	}

	if query.IsDuration() {
		labels := b.buildLabelMatchers(query, filter)
		mult := query.Multiplier
		if mult == 0 {
			mult = 1
		}
		return fmt.Sprintf("sum(rate(%s{%s}[%s])) / sum(rate(%s{%s}[%s])) * %g",
			query.DurationMetric, labels, rangeDur,
			query.DurationCountMetric, labels, rangeDur,
			mult)
	}

	labels := b.buildLabelMatchers(query, filter)
	selector := fmt.Sprintf("%s{%s}", query.Metric, labels)

	var expr string
	switch query.Aggregation {
	case AggGauge:
		if query.GroupBy != "" {
			expr = fmt.Sprintf("sum by (%s) (%s)", query.GroupBy, selector)
		} else {
			expr = fmt.Sprintf("sum(%s)", selector)
		}
	case AggCount:
		if query.GroupBy != "" {
			expr = fmt.Sprintf("sum by (%s) (increase(%s[%s]))", query.GroupBy, selector, rangeDur)
		} else {
			expr = fmt.Sprintf("sum(increase(%s[%s]))", selector, rangeDur)
		}
	case AggSum:
		if query.GroupBy != "" {
			expr = fmt.Sprintf("sum by (%s) (increase(%s[%s]))", query.GroupBy, selector, rangeDur)
		} else {
			expr = fmt.Sprintf("sum(increase(%s[%s]))", selector, rangeDur)
		}
	case AggAvg:
		if query.GroupBy != "" {
			expr = fmt.Sprintf("avg by (%s) (increase(%s[%s]))", query.GroupBy, selector, rangeDur)
		} else {
			expr = fmt.Sprintf("avg(increase(%s[%s]))", selector, rangeDur)
		}
	case AggCountDistinct:
		if query.GroupBy != "" {
			expr = fmt.Sprintf("count(count by (%s) (increase(%s[%s])))", query.GroupBy, selector, rangeDur)
		} else {
			expr = fmt.Sprintf("count(increase(%s[%s]))", selector, rangeDur)
		}
	default:
		expr = fmt.Sprintf("sum(increase(%s[%s]))", selector, rangeDur)
	}

	return expr
}

// buildRatePromQL constructs a PromQL expression suitable for range queries
// (used by QueryTimeSeries). Uses rate() with the step duration.
func (b *PrometheusBackend) buildRatePromQL(query MetricQuery, filter TenantFilter, step time.Duration) string {
	labels := b.buildLabelMatchers(query, filter)
	selector := fmt.Sprintf("%s{%s}", query.Metric, labels)
	stepDur := formatDuration(step)

	switch query.Aggregation {
	case AggGauge:
		return fmt.Sprintf("sum(%s)", selector)
	default:
		return fmt.Sprintf("sum(increase(%s[%s]))", selector, stepDur)
	}
}

// buildLabelMatchers constructs the Prometheus label matcher string combining
// tenant/partition scope with any static query filters.
func (b *PrometheusBackend) buildLabelMatchers(query MetricQuery, filter TenantFilter) string {
	var parts []string

	if filter.Scoped {
		parts = append(parts, fmt.Sprintf(`tenant_id="%s"`, filter.TenantID))
		if len(filter.PartitionIDs) == 1 {
			parts = append(parts, fmt.Sprintf(`partition_id="%s"`, filter.PartitionIDs[0]))
		} else if len(filter.PartitionIDs) > 1 {
			parts = append(parts, fmt.Sprintf(`partition_id=~"%s"`, strings.Join(filter.PartitionIDs, "|")))
		}
	}

	for k, v := range query.Filters {
		parts = append(parts, fmt.Sprintf(`%s="%s"`, k, v))
	}

	return strings.Join(parts, ",")
}

// formatDuration converts a Go duration to Prometheus duration syntax.
func formatDuration(d time.Duration) string {
	hours := int(d.Hours())
	if hours >= 24 {
		return fmt.Sprintf("%dd", hours/24)
	}
	if hours > 0 {
		return fmt.Sprintf("%dh", hours)
	}
	minutes := int(d.Minutes())
	if minutes > 0 {
		return fmt.Sprintf("%dm", minutes)
	}
	return "1m"
}

// firstNonEmptyLabel returns the first non-empty label value from a metric,
// preferring common entity-name labels.
func firstNonEmptyLabel(metric map[string]string) string {
	preferred := []string{"name", "label", "instance", "recipient", "customer_name",
		"actor_name", "template_name", "uploader", "area_name", "display_name", "tenant_name"}
	for _, key := range preferred {
		if v, ok := metric[key]; ok && v != "" {
			return v
		}
	}
	for k, v := range metric {
		if v != "" && k != "__name__" {
			return v
		}
	}
	return "unknown"
}

// --- Prometheus HTTP API ---

type promResponse struct {
	Status    string   `json:"status"`
	Data      promData `json:"data"`
	ErrorType string   `json:"errorType,omitempty"`
	Error     string   `json:"error,omitempty"`
}

type promData struct {
	ResultType string          `json:"resultType"`
	Result     json.RawMessage `json:"result"`
}

type vectorResult struct {
	Metric map[string]string `json:"metric"`
	Value  promSample        `json:"value"`
}

type matrixResult struct {
	Metric map[string]string `json:"metric"`
	Values []promSample      `json:"values"`
}

type promSample [2]json.RawMessage

func (s promSample) Time() (time.Time, error) {
	var ts float64
	if err := json.Unmarshal(s[0], &ts); err != nil {
		return time.Time{}, err
	}
	sec := int64(ts)
	nsec := int64((ts - float64(sec)) * 1e9)
	return time.Unix(sec, nsec), nil
}

func (s promSample) Float64() (float64, error) {
	var str string
	if err := json.Unmarshal(s[1], &str); err != nil {
		return 0, err
	}
	return strconv.ParseFloat(str, 64)
}

func (b *PrometheusBackend) instantQuery(ctx context.Context, query string, ts time.Time) ([]vectorResult, error) {
	params := url.Values{
		"query": {query},
		"time":  {formatPrometheusTime(ts)},
	}

	resp, err := b.apiGet(ctx, "/api/v1/query", params)
	if err != nil {
		return nil, err
	}

	if resp.Data.ResultType != "vector" {
		return nil, fmt.Errorf("expected vector result, got %s", resp.Data.ResultType)
	}

	var results []vectorResult
	if err := json.Unmarshal(resp.Data.Result, &results); err != nil {
		return nil, fmt.Errorf("unmarshal vector: %w", err)
	}
	return results, nil
}

func (b *PrometheusBackend) rangeQuery(ctx context.Context, query string, start, end time.Time, step time.Duration) ([]matrixResult, error) {
	params := url.Values{
		"query": {query},
		"start": {formatPrometheusTime(start)},
		"end":   {formatPrometheusTime(end)},
		"step":  {step.String()},
	}

	resp, err := b.apiGet(ctx, "/api/v1/query_range", params)
	if err != nil {
		return nil, err
	}

	if resp.Data.ResultType != "matrix" {
		return nil, fmt.Errorf("expected matrix result, got %s", resp.Data.ResultType)
	}

	var results []matrixResult
	if err := json.Unmarshal(resp.Data.Result, &results); err != nil {
		return nil, fmt.Errorf("unmarshal matrix: %w", err)
	}
	return results, nil
}

func (b *PrometheusBackend) apiGet(ctx context.Context, path string, params url.Values) (*promResponse, error) {
	reqURL := b.baseURL + path + "?" + params.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")

	resp, err := b.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("metrics query: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read metrics response: %w", err)
	}

	var pr promResponse
	if err := json.Unmarshal(body, &pr); err != nil {
		return nil, fmt.Errorf("decode metrics response: %w", err)
	}

	if pr.Status != "success" {
		return nil, fmt.Errorf("metrics error (%s): %s", pr.ErrorType, pr.Error)
	}

	return &pr, nil
}

func formatPrometheusTime(t time.Time) string {
	return strconv.FormatFloat(float64(t.UnixNano())/1e9, 'f', 3, 64)
}
