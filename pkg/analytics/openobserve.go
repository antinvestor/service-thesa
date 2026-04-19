package analytics

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// OpenObserveBackend implements MetricsBackend by querying OpenObserve's
// Prometheus-compatible API. OpenObserve exposes PromQL queries at
// /api/{org}/prometheus/api/v1/... and requires basic-auth or token auth.
type OpenObserveBackend struct {
	prom *PrometheusBackend
	org  string
}

var _ MetricsBackend = (*OpenObserveBackend)(nil)

// NewOpenObserveBackend creates a backend targeting an OpenObserve instance.
// baseURL is the OpenObserve root (e.g. "http://openobserve:5080"), org is the
// OpenObserve organization name (defaults to "default"). The HTTP client should
// already carry any required auth (see OpenObserveAuthTransport).
func NewOpenObserveBackend(baseURL string, org string, client *http.Client) *OpenObserveBackend {
	if org == "" {
		org = "default"
	}
	baseURL = strings.TrimRight(baseURL, "/")

	// OpenObserve's Prometheus-compatible API lives under /api/{org}/prometheus.
	// The wrapped PrometheusBackend appends /api/v1/query etc., producing the
	// correct full path: /api/{org}/prometheus/api/v1/query.
	promBase := fmt.Sprintf("%s/api/%s/prometheus", baseURL, org)
	prom := NewPrometheusBackend(promBase, client)

	return &OpenObserveBackend{prom: prom, org: org}
}

func (b *OpenObserveBackend) QueryScalar(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange) (float64, error) {
	return b.prom.QueryScalar(ctx, query, filter, tr)
}

func (b *OpenObserveBackend) QueryTimeSeries(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, step time.Duration) ([]TimeSeriesPoint, error) {
	return b.prom.QueryTimeSeries(ctx, query, filter, tr, step)
}

func (b *OpenObserveBackend) QueryGrouped(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, groupBy string) ([]LabelValue, error) {
	return b.prom.QueryGrouped(ctx, query, filter, tr, groupBy)
}

func (b *OpenObserveBackend) QueryTopN(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, groupBy string, limit int) ([]LabelValue, error) {
	return b.prom.QueryTopN(ctx, query, filter, tr, groupBy, limit)
}

// Healthy checks OpenObserve reachability via its Prometheus-compatible
// labels endpoint. The `/api/v1/status/buildinfo` route used by
// PrometheusBackend.Healthy is not implemented by OpenObserve and returns
// 401 regardless of credentials.
func (b *OpenObserveBackend) Healthy(ctx context.Context) error {
	reqURL := fmt.Sprintf("%s/api/v1/labels", b.prom.baseURL)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return err
	}
	resp, err := b.prom.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("metrics backend health check: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("metrics backend returned status %d", resp.StatusCode)
	}
	return nil
}

// OpenObserveAuthTransport is an http.RoundTripper that injects basic-auth
// credentials into every request. Use it to wrap an existing transport when
// constructing the HTTP client for OpenObserveBackend.
type OpenObserveAuthTransport struct {
	Username string
	Password string
	Base     http.RoundTripper
}

func (t *OpenObserveAuthTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	r := req.Clone(req.Context())
	r.SetBasicAuth(t.Username, t.Password)
	base := t.Base
	if base == nil {
		base = http.DefaultTransport
	}
	return base.RoundTrip(r)
}

// NewOpenObserveHTTPClient creates an HTTP client that injects OpenObserve
// basic-auth credentials into every request. If base is nil,
// http.DefaultTransport is used.
func NewOpenObserveHTTPClient(username, password string, base http.RoundTripper) *http.Client {
	return &http.Client{
		Timeout: 30 * time.Second,
		Transport: &OpenObserveAuthTransport{
			Username: username,
			Password: password,
			Base:     base,
		},
	}
}
