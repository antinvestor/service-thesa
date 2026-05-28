package analytics

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// UptraceBackend implements MetricsBackend by querying Uptrace's
// Prometheus-compatible API at /api/v1/prometheus/api/v1/... .
//
// Uptrace authenticates via a project token passed as a bearer token in
// the Authorization header (see UptraceAuthTransport).
type UptraceBackend struct {
	prom *PrometheusBackend
}

var _ MetricsBackend = (*UptraceBackend)(nil)

// NewUptraceBackend creates a backend targeting an Uptrace instance.
// baseURL is the Uptrace root (e.g. "https://uptrace.stawi.org").
// The HTTP client should already carry the project token (see
// UptraceAuthTransport / NewUptraceHTTPClient).
func NewUptraceBackend(baseURL string, client *http.Client) *UptraceBackend {
	baseURL = strings.TrimRight(baseURL, "/")
	// Uptrace exposes PromQL at /api/v1/prometheus/api/v1/<endpoint>. The
	// wrapped PrometheusBackend appends /api/v1/query etc., producing the
	// correct full path.
	promBase := fmt.Sprintf("%s/api/v1/prometheus", baseURL)
	prom := NewPrometheusBackend(promBase, client)
	return &UptraceBackend{prom: prom}
}

func (b *UptraceBackend) QueryScalar(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange) (float64, error) {
	return b.prom.QueryScalar(ctx, query, filter, tr)
}

func (b *UptraceBackend) QueryTimeSeries(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, step time.Duration) ([]TimeSeriesPoint, error) {
	return b.prom.QueryTimeSeries(ctx, query, filter, tr, step)
}

func (b *UptraceBackend) QueryGrouped(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, groupBy string) ([]LabelValue, error) {
	return b.prom.QueryGrouped(ctx, query, filter, tr, groupBy)
}

func (b *UptraceBackend) QueryTopN(ctx context.Context, query MetricQuery, filter TenantFilter, tr TimeRange, groupBy string, limit int) ([]LabelValue, error) {
	return b.prom.QueryTopN(ctx, query, filter, tr, groupBy, limit)
}

// Healthy reuses Prometheus' /api/v1/labels endpoint, which Uptrace
// implements. /api/v1/status/buildinfo is not exposed.
func (b *UptraceBackend) Healthy(ctx context.Context) error {
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

// UptraceAuthTransport injects an Uptrace project token into every
// request via the Authorization header.
type UptraceAuthTransport struct {
	Token string
	Base  http.RoundTripper
}

func (t *UptraceAuthTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	r := req.Clone(req.Context())
	r.Header.Set("Authorization", "Bearer "+t.Token)
	base := t.Base
	if base == nil {
		base = http.DefaultTransport
	}
	return base.RoundTrip(r)
}

// NewUptraceHTTPClient creates an HTTP client that injects an Uptrace
// project token into every request. If base is nil,
// http.DefaultTransport is used.
func NewUptraceHTTPClient(token string, base http.RoundTripper) *http.Client {
	return &http.Client{
		Timeout: 30 * time.Second,
		Transport: &UptraceAuthTransport{
			Token: token,
			Base:  base,
		},
	}
}
