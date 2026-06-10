package analytics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

const testToken = "uptrace-secret-token-xyz" //nolint:gosec // test fixture, not a credential

type recordedRequest struct {
	Path          string
	Query         string
	Authorization string
}

// promAPIStub is an httptest mock of the Prometheus HTTP API that records
// every request.
type promAPIStub struct {
	mu       sync.Mutex
	requests []recordedRequest
	status   int // 0 means 200 with a success payload
}

func (s *promAPIStub) handler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		s.mu.Lock()
		s.requests = append(s.requests, recordedRequest{
			Path:          r.URL.Path,
			Query:         r.URL.Query().Get("query"),
			Authorization: r.Header.Get("Authorization"),
		})
		status := s.status
		s.mu.Unlock()

		w.Header().Set("Content-Type", "application/json")
		if status != 0 && status != http.StatusOK {
			w.WriteHeader(status)
			_, _ = w.Write([]byte(`{"status":"error","errorType":"unavailable","error":"backend overloaded"}`))
			return
		}
		if strings.HasSuffix(r.URL.Path, "/query_range") {
			_, _ = w.Write([]byte(`{"status":"success","data":{"resultType":"matrix","result":[{"metric":{},"values":[[1700000000,"5"]]}]}}`))
			return
		}
		_, _ = w.Write([]byte(`{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1700000000,"42"]}]}}`))
	}
}

func (s *promAPIStub) recorded(t *testing.T) []recordedRequest {
	t.Helper()
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]recordedRequest, len(s.requests))
	copy(out, s.requests)
	return out
}

func newUptraceTestBackend(t *testing.T, stub *promAPIStub) (*UptraceBackend, string) {
	t.Helper()
	srv := httptest.NewServer(stub.handler())
	t.Cleanup(srv.Close)

	base := srv.URL + "/api/prometheus/7777"
	client := NewUptraceHTTPClient(testToken, nil)
	return NewUptraceBackend(base, client), base
}

func scopedFilter() TenantFilter {
	return TenantFilter{TenantID: "acme-corp", PartitionIDs: []string{"part-01"}, Scoped: true}
}

func TestUptraceBackend_QueryScalar_SendsBearerTokenAndQueryPath(t *testing.T) {
	stub := &promAPIStub{}
	backend, _ := newUptraceTestBackend(t, stub)

	val, err := backend.QueryScalar(t.Context(),
		MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum},
		scopedFilter(), testTimeRange())

	if err != nil {
		t.Fatalf("QueryScalar() error = %v", err)
	}
	if val != 42 {
		t.Errorf("QueryScalar() = %v, want 42", val)
	}

	reqs := stub.recorded(t)
	if len(reqs) != 1 {
		t.Fatalf("backend requests = %d, want 1", len(reqs))
	}
	if want := "/api/prometheus/7777/api/v1/query"; reqs[0].Path != want {
		t.Errorf("request path = %q, want %q (base URL must be used as-is)", reqs[0].Path, want)
	}
	if want := "Bearer " + testToken; reqs[0].Authorization != want {
		t.Errorf("Authorization = %q, want %q", reqs[0].Authorization, want)
	}
	if !strings.Contains(reqs[0].Query, `tenant_id="acme-corp"`) {
		t.Errorf("PromQL missing tenant matcher: %s", reqs[0].Query)
	}
	if !strings.Contains(reqs[0].Query, `partition_id="part-01"`) {
		t.Errorf("PromQL missing partition matcher: %s", reqs[0].Query)
	}
}

func TestUptraceBackend_QueryTimeSeries_HitsQueryRangePath(t *testing.T) {
	stub := &promAPIStub{}
	backend, _ := newUptraceTestBackend(t, stub)

	points, err := backend.QueryTimeSeries(t.Context(),
		MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum},
		scopedFilter(), testTimeRange(), time.Hour)

	if err != nil {
		t.Fatalf("QueryTimeSeries() error = %v", err)
	}
	if len(points) != 1 || points[0].Value != 5 {
		t.Errorf("QueryTimeSeries() = %v, want one point of value 5", points)
	}

	reqs := stub.recorded(t)
	if len(reqs) != 1 {
		t.Fatalf("backend requests = %d, want 1", len(reqs))
	}
	if want := "/api/prometheus/7777/api/v1/query_range"; reqs[0].Path != want {
		t.Errorf("request path = %q, want %q", reqs[0].Path, want)
	}
}

func TestUptraceBackend_Non200SurfacesStatusWithoutLeakingToken(t *testing.T) {
	tests := []struct {
		name      string
		status    int
		wantInMsg string
	}{
		{name: "unauthorized", status: http.StatusUnauthorized, wantInMsg: "401"},
		{name: "rate limited", status: http.StatusTooManyRequests, wantInMsg: "429"},
		{name: "unavailable", status: http.StatusServiceUnavailable, wantInMsg: "503"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			stub := &promAPIStub{status: tc.status}
			backend, _ := newUptraceTestBackend(t, stub)

			_, err := backend.QueryScalar(t.Context(),
				MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum},
				scopedFilter(), testTimeRange())

			if err == nil {
				t.Fatal("QueryScalar() error = nil, want upstream status error")
			}
			if !strings.Contains(err.Error(), tc.wantInMsg) {
				t.Errorf("error %q must carry upstream status %s", err, tc.wantInMsg)
			}
			if strings.Contains(err.Error(), testToken) {
				t.Errorf("error leaks the bearer token: %q", err)
			}
		})
	}
}

func TestBuildLabelMatchers_NormalizationAndEscaping(t *testing.T) {
	b := NewPrometheusBackend("http://prom", nil)

	tests := []struct {
		name   string
		query  MetricQuery
		filter TenantFilter
		want   []string
		absent []string
	}{
		{
			name:   "dotted attribute keys use underscore form",
			query:  MetricQuery{Filters: map[string]string{"service.name": "loans-svc"}},
			filter: scopedFilter(),
			want:   []string{`service_name="loans-svc"`},
			absent: []string{"service.name"},
		},
		{
			name:   "client tenancy filters are dropped",
			query:  MetricQuery{Filters: map[string]string{"tenant_id": "victim", "partition.id": "victim"}},
			filter: scopedFilter(),
			want:   []string{`tenant_id="acme-corp"`, `partition_id="part-01"`},
			absent: []string{"victim"},
		},
		{
			name:   "label values are escaped against PromQL injection",
			query:  MetricQuery{Filters: map[string]string{"status": `ok"} or up{x="`}},
			filter: scopedFilter(),
			want:   []string{`status="ok\"} or up{x=\""`},
		},
		{
			name:   "multiple partitions become an escaped regex matcher",
			query:  MetricQuery{},
			filter: TenantFilter{TenantID: "t1", PartitionIDs: []string{"p.1", "p2"}, Scoped: true},
			want:   []string{`partition_id=~"p\\.1|p2"`},
		},
		{
			name:   "unscoped filter omits tenancy matchers",
			query:  MetricQuery{Filters: map[string]string{"status": "ok"}},
			filter: TenantFilter{},
			want:   []string{`status="ok"`},
			absent: []string{"tenant_id", "partition_id"},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := b.buildLabelMatchers(tc.query, tc.filter)
			for _, w := range tc.want {
				if !strings.Contains(got, w) {
					t.Errorf("buildLabelMatchers() = %q, missing %q", got, w)
				}
			}
			for _, a := range tc.absent {
				if strings.Contains(got, a) {
					t.Errorf("buildLabelMatchers() = %q, must not contain %q", got, a)
				}
			}
		})
	}
}

func TestSanitizeMetricName_UptraceUnderscoreForm(t *testing.T) {
	tests := []struct {
		in   string
		want string
	}{
		{"loans_disbursed_total", "loans_disbursed_total"},
		{"engine.commands.executed", "engine_commands_executed"},
		{"devices/active_count", "devices_active_count"},
		{"gocloud.dev/pubsub/latency", "gocloud_dev_pubsub_latency"},
		{`evil{} or up`, "evil___or_up"},
	}
	for _, tc := range tests {
		if got := sanitizeMetricName(tc.in); got != tc.want {
			t.Errorf("sanitizeMetricName(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}
