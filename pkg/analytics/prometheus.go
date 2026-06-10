package analytics

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"sort"
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

	groupLabel := sanitizeLabelName(groupBy)
	items := make([]LabelValue, 0, len(results))
	for _, r := range results {
		val, _ := r.Value.Float64()
		label := r.Metric[groupLabel]
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

	groupLabel := sanitizeLabelName(groupBy)
	items := make([]LabelValue, 0, len(results))
	for _, r := range results {
		val, _ := r.Value.Float64()
		label := r.Metric[groupLabel]
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
			sanitizeMetricName(query.DurationMetric), labels, rangeDur,
			sanitizeMetricName(query.DurationCountMetric), labels, rangeDur,
			mult)
	}

	labels := b.buildLabelMatchers(query, filter)
	selector := fmt.Sprintf("%s{%s}", sanitizeMetricName(query.Metric), labels)
	groupBy := sanitizeLabelName(query.GroupBy)

	var expr string
	switch query.Aggregation {
	case AggGauge:
		if groupBy != "" {
			expr = fmt.Sprintf("sum by (%s) (%s)", groupBy, selector)
		} else {
			expr = fmt.Sprintf("sum(%s)", selector)
		}
	case AggCount:
		if groupBy != "" {
			expr = fmt.Sprintf("sum by (%s) (increase(%s[%s]))", groupBy, selector, rangeDur)
		} else {
			expr = fmt.Sprintf("sum(increase(%s[%s]))", selector, rangeDur)
		}
	case AggSum:
		if groupBy != "" {
			expr = fmt.Sprintf("sum by (%s) (increase(%s[%s]))", groupBy, selector, rangeDur)
		} else {
			expr = fmt.Sprintf("sum(increase(%s[%s]))", selector, rangeDur)
		}
	case AggAvg:
		if groupBy != "" {
			expr = fmt.Sprintf("avg by (%s) (increase(%s[%s]))", groupBy, selector, rangeDur)
		} else {
			expr = fmt.Sprintf("avg(increase(%s[%s]))", selector, rangeDur)
		}
	case AggCountDistinct:
		if groupBy != "" {
			expr = fmt.Sprintf("count(count by (%s) (increase(%s[%s])))", groupBy, selector, rangeDur)
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
	selector := fmt.Sprintf("%s{%s}", sanitizeMetricName(query.Metric), labels)
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
//
// The tenant_id/partition_id matchers always come from the resolved
// TenantFilter; client filters on those labels are dropped so they can never
// widen or redirect the tenancy scope. Label keys are normalized to
// underscore form (Uptrace normalizes attribute keys dot->underscore, e.g.
// service.name becomes service_name) and values are escaped for PromQL.
func (b *PrometheusBackend) buildLabelMatchers(query MetricQuery, filter TenantFilter) string {
	var parts []string

	if filter.Scoped {
		parts = append(parts, fmt.Sprintf(`tenant_id="%s"`, escapeLabelValue(filter.TenantID)))
		if len(filter.PartitionIDs) == 1 {
			parts = append(parts, fmt.Sprintf(`partition_id="%s"`, escapeLabelValue(filter.PartitionIDs[0])))
		} else if len(filter.PartitionIDs) > 1 {
			quoted := make([]string, len(filter.PartitionIDs))
			for i, id := range filter.PartitionIDs {
				quoted[i] = regexp.QuoteMeta(id)
			}
			parts = append(parts, fmt.Sprintf(`partition_id=~"%s"`, escapeLabelValue(strings.Join(quoted, "|"))))
		}
	}

	keys := make([]string, 0, len(query.Filters))
	for k := range query.Filters {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		name := sanitizeLabelName(k)
		if isReservedScopeLabel(name) {
			continue
		}
		parts = append(parts, fmt.Sprintf(`%s="%s"`, name, escapeLabelValue(query.Filters[k])))
	}

	return strings.Join(parts, ",")
}

// isReservedScopeLabel reports whether a (normalized) label name is reserved
// for server-side tenancy scoping and must never be client-controlled.
func isReservedScopeLabel(name string) bool {
	return name == "tenant_id" || name == "partition_id"
}

// labelNameSanitizer matches every character that is not valid in a
// Prometheus label name.
var labelNameSanitizer = regexp.MustCompile(`[^a-zA-Z0-9_]`)

// metricNameSanitizer matches every character that is not valid in a
// Prometheus metric name.
var metricNameSanitizer = regexp.MustCompile(`[^a-zA-Z0-9_:]`)

// sanitizeLabelName normalizes an attribute key into a valid Prometheus label
// name. Uptrace applies the same normalization when ingesting OTel attributes
// (dots become underscores: service.name -> service_name).
func sanitizeLabelName(name string) string {
	s := labelNameSanitizer.ReplaceAllString(name, "_")
	if s != "" && s[0] >= '0' && s[0] <= '9' {
		s = "_" + s
	}
	return s
}

// sanitizeMetricName normalizes an OTel metric name into the Prometheus form
// Uptrace exposes (dots and slashes become underscores), and in doing so
// guarantees the name cannot inject PromQL syntax.
func sanitizeMetricName(name string) string {
	s := metricNameSanitizer.ReplaceAllString(name, "_")
	if s != "" && s[0] >= '0' && s[0] <= '9' {
		s = "_" + s
	}
	return s
}

// escapeLabelValue escapes a string for inclusion in a double-quoted PromQL
// label matcher value.
func escapeLabelValue(v string) string {
	r := strings.NewReplacer(`\`, `\\`, `"`, `\"`, "\n", `\n`)
	return r.Replace(v)
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

	// Surface non-200 responses with the upstream status. The error must never
	// include request headers or the bearer token — only status and the
	// backend's own error body (when it is a valid Prometheus error payload).
	if resp.StatusCode != http.StatusOK {
		var pr promResponse
		if jerr := json.Unmarshal(body, &pr); jerr == nil && pr.Error != "" {
			return nil, fmt.Errorf("metrics backend returned status %d (%s): %s",
				resp.StatusCode, pr.ErrorType, pr.Error)
		}
		return nil, fmt.Errorf("metrics backend returned status %d", resp.StatusCode)
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
