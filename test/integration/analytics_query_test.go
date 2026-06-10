package integration

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/antinvestor/service-thesa/pkg/analytics"
)

const testUptraceToken = "uptrace-project-token-secret" //nolint:gosec // test fixture, not a credential

// promRecorder captures requests received by the mock Prometheus API.
type promRecorder struct {
	mu       sync.Mutex
	requests []promRequest
	failWith int // when >0, every request is answered with this status
}

type promRequest struct {
	Path          string
	Query         string
	Authorization string
}

func (r *promRecorder) add(req promRequest) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.requests = append(r.requests, req)
}

func (r *promRecorder) all() []promRequest {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]promRequest, len(r.requests))
	copy(out, r.requests)
	return out
}

// newMockPromAPI starts an httptest mock of the Prometheus HTTP API
// (instant vector for /api/v1/query, matrix for /api/v1/query_range).
func newMockPromAPI(t *testing.T, rec *promRecorder) *httptest.Server {
	t.Helper()

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rec.add(promRequest{
			Path:          r.URL.Path,
			Query:         r.URL.Query().Get("query"),
			Authorization: r.Header.Get("Authorization"),
		})

		w.Header().Set("Content-Type", "application/json")
		if rec.failWith > 0 {
			w.WriteHeader(rec.failWith)
			_, _ = w.Write([]byte(`{"status":"error","errorType":"unavailable","error":"backend overloaded"}`))
			return
		}
		if strings.HasSuffix(r.URL.Path, "/query_range") {
			_, _ = w.Write([]byte(`{"status":"success","data":{"resultType":"matrix","result":[{"metric":{},"values":[[1700000000,"5"],[1700003600,"6"]]}]}}`))
			return
		}
		_, _ = w.Write([]byte(`{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1700000000,"42"]}]}}`))
	}))
	t.Cleanup(srv.Close)
	return srv
}

// newAnalyticsHarness wires a full BFF harness whose analytics engine talks
// to an Uptrace backend pointed at a mock Prometheus API.
func newAnalyticsHarness(t *testing.T, engineOpts ...analytics.EngineOption) (*TestHarness, *promRecorder) {
	t.Helper()

	rec := &promRecorder{}
	srv := newMockPromAPI(t, rec)

	client := analytics.NewUptraceHTTPClient(testUptraceToken, nil)
	backend := analytics.NewUptraceBackend(srv.URL+"/api/prometheus/7777", client)

	engine, err := analytics.NewEngine(backend, nil, engineOpts...)
	if err != nil {
		t.Fatalf("NewEngine() error = %v", err)
	}

	h := NewTestHarness(t, WithAnalyticsEngine(engine))
	return h, rec
}

func analyticsClaims() TestClaims {
	return TestClaims{
		SubjectID:   "user-analyst",
		TenantID:    "acme-corp",
		PartitionID: "part-01",
		Email:       "analyst@acme.example.com",
		Roles:       []string{"order_viewer"},
	}
}

func scalarRequestBody() map[string]any {
	return map[string]any{
		"metric":      "loans_disbursed_total",
		"aggregation": "sum",
		"time_range": map[string]string{
			"start": "2026-06-01T00:00:00Z",
			"end":   "2026-06-08T00:00:00Z",
		},
	}
}

func TestAnalyticsScalar_CarriesTenantScopeAndBearerToken(t *testing.T) {
	h, rec := newAnalyticsHarness(t, analytics.WithCacheTTL(0))
	token := h.GenerateToken(analyticsClaims())

	resp := h.POST("/api/analytics/query/scalar", scalarRequestBody(), token)

	var result map[string]float64
	h.AssertJSON(t, resp, http.StatusOK, &result)
	if result["value"] != 42 {
		t.Errorf("value = %v, want 42", result["value"])
	}

	reqs := rec.all()
	if len(reqs) != 1 {
		t.Fatalf("backend requests = %d, want 1", len(reqs))
	}
	if want := "/api/prometheus/7777/api/v1/query"; reqs[0].Path != want {
		t.Errorf("backend path = %q, want %q (ANALYTICS_BACKEND_URL must be used as-is)", reqs[0].Path, want)
	}
	if want := "Bearer " + testUptraceToken; reqs[0].Authorization != want {
		t.Errorf("Authorization = %q, want %q", reqs[0].Authorization, want)
	}
	if !strings.Contains(reqs[0].Query, `tenant_id="acme-corp"`) {
		t.Errorf("PromQL missing tenant matcher: %s", reqs[0].Query)
	}
	if !strings.Contains(reqs[0].Query, `partition_id="part-01"`) {
		t.Errorf("PromQL missing partition matcher: %s", reqs[0].Query)
	}
}

func TestAnalyticsTimeSeries_UsesQueryRangeEndpoint(t *testing.T) {
	h, rec := newAnalyticsHarness(t, analytics.WithCacheTTL(0))
	token := h.GenerateToken(analyticsClaims())

	body := scalarRequestBody()
	body["step"] = "hour"
	resp := h.POST("/api/analytics/query/timeseries", body, token)

	var result map[string]any
	h.AssertJSON(t, resp, http.StatusOK, &result)
	points, ok := result["points"].([]any)
	if !ok || len(points) != 2 {
		t.Errorf("points = %v, want 2 entries", result["points"])
	}

	reqs := rec.all()
	if len(reqs) != 1 {
		t.Fatalf("backend requests = %d, want 1", len(reqs))
	}
	if want := "/api/prometheus/7777/api/v1/query_range"; reqs[0].Path != want {
		t.Errorf("backend path = %q, want %q", reqs[0].Path, want)
	}
	if !strings.Contains(reqs[0].Query, `tenant_id="acme-corp"`) {
		t.Errorf("PromQL missing tenant matcher: %s", reqs[0].Query)
	}
}

func TestAnalyticsScalar_CrossTenantFilterAttemptIsNeutralized(t *testing.T) {
	h, rec := newAnalyticsHarness(t, analytics.WithCacheTTL(0))
	token := h.GenerateToken(analyticsClaims())

	body := scalarRequestBody()
	body["filters"] = map[string]string{
		"tenant_id":    "victim-tenant",
		"partition_id": "victim-partition",
		"status":       "approved",
	}
	resp := h.POST("/api/analytics/query/scalar", body, token)
	h.AssertStatus(t, resp, http.StatusOK)
	_ = resp.Body.Close()

	reqs := rec.all()
	if len(reqs) != 1 {
		t.Fatalf("backend requests = %d, want 1", len(reqs))
	}
	q := reqs[0].Query
	if strings.Contains(q, "victim") {
		t.Errorf("client-supplied tenancy filter reached the backend: %s", q)
	}
	if !strings.Contains(q, `tenant_id="acme-corp"`) {
		t.Errorf("authoritative tenant matcher missing: %s", q)
	}
	if got := strings.Count(q, "tenant_id="); got != 1 {
		t.Errorf("tenant_id matcher count = %d, want exactly 1: %s", got, q)
	}
	if !strings.Contains(q, `status="approved"`) {
		t.Errorf("legitimate filter was dropped: %s", q)
	}
}

func TestAnalyticsScalar_RequestWithoutTenantClaimsRejectedWith403(t *testing.T) {
	h, rec := newAnalyticsHarness(t, analytics.WithCacheTTL(0))
	token := h.GenerateToken(TestClaims{
		SubjectID: "user-no-tenant",
		Email:     "drifter@example.com",
		Roles:     []string{"order_viewer"},
	})

	resp := h.POST("/api/analytics/query/scalar", scalarRequestBody(), token)

	h.AssertStatus(t, resp, http.StatusForbidden)
	_ = resp.Body.Close()
	if got := len(rec.all()); got != 0 {
		t.Errorf("backend requests = %d, want 0: rejected queries must never reach the backend", got)
	}
}

func TestAnalyticsScalar_GlobalCapabilityAllowsUnscopedQuery(t *testing.T) {
	h, rec := newAnalyticsHarness(t, analytics.WithCacheTTL(0))
	// platform_observer carries analytics:global:view in testdata/policies.yaml.
	token := h.GenerateToken(TestClaims{
		SubjectID: "user-platform",
		Email:     "platform@example.com",
		Roles:     []string{"platform_observer"},
	})

	resp := h.POST("/api/analytics/query/scalar", scalarRequestBody(), token)

	var result map[string]float64
	h.AssertJSON(t, resp, http.StatusOK, &result)
	if result["value"] != 42 {
		t.Errorf("value = %v, want 42", result["value"])
	}

	reqs := rec.all()
	if len(reqs) != 1 {
		t.Fatalf("backend requests = %d, want 1", len(reqs))
	}
	if strings.Contains(reqs[0].Query, "tenant_id=") {
		t.Errorf("global query must be unscoped, got: %s", reqs[0].Query)
	}
}

func TestAnalyticsScalar_RepeatRequestWithinTTLServedFromCache(t *testing.T) {
	h, rec := newAnalyticsHarness(t, analytics.WithCacheTTL(2*time.Minute))
	token := h.GenerateToken(analyticsClaims())

	for i := 0; i < 2; i++ {
		resp := h.POST("/api/analytics/query/scalar", scalarRequestBody(), token)
		var result map[string]float64
		h.AssertJSON(t, resp, http.StatusOK, &result)
		if result["value"] != 42 {
			t.Errorf("request %d: value = %v, want 42", i+1, result["value"])
		}
	}

	if got := len(rec.all()); got != 1 {
		t.Errorf("backend requests = %d, want 1: second identical request within TTL must hit the cache", got)
	}
}

func TestAnalyticsScalar_DisallowedMetricRejectedWith400(t *testing.T) {
	h, rec := newAnalyticsHarness(t, analytics.WithCacheTTL(0))
	token := h.GenerateToken(analyticsClaims())

	body := scalarRequestBody()
	body["metric"] = "node_cpu_seconds_total"
	resp := h.POST("/api/analytics/query/scalar", body, token)

	h.AssertStatus(t, resp, http.StatusBadRequest)
	_ = resp.Body.Close()
	if got := len(rec.all()); got != 0 {
		t.Errorf("backend requests = %d, want 0", got)
	}
}

func TestAnalyticsScalar_DottedFilterKeysUseUnderscoreForm(t *testing.T) {
	h, rec := newAnalyticsHarness(t, analytics.WithCacheTTL(0))
	token := h.GenerateToken(analyticsClaims())

	body := scalarRequestBody()
	body["filters"] = map[string]string{"service.name": "loans-svc"}
	resp := h.POST("/api/analytics/query/scalar", body, token)
	h.AssertStatus(t, resp, http.StatusOK)
	_ = resp.Body.Close()

	reqs := rec.all()
	if len(reqs) != 1 {
		t.Fatalf("backend requests = %d, want 1", len(reqs))
	}
	if !strings.Contains(reqs[0].Query, `service_name="loans-svc"`) {
		t.Errorf("dotted attribute key not normalized to underscore form: %s", reqs[0].Query)
	}
}

func TestAnalyticsScalar_BackendFailureReturns500WithoutTokenLeak(t *testing.T) {
	h, rec := newAnalyticsHarness(t, analytics.WithCacheTTL(0))
	rec.failWith = http.StatusServiceUnavailable
	token := h.GenerateToken(analyticsClaims())

	resp := h.POST("/api/analytics/query/scalar", scalarRequestBody(), token)

	if resp.StatusCode != http.StatusInternalServerError {
		t.Errorf("status = %d, want 500", resp.StatusCode)
	}
	body := string(h.ReadBody(resp))
	if strings.Contains(body, testUptraceToken) {
		t.Errorf("response leaks the bearer token: %s", body)
	}
}
