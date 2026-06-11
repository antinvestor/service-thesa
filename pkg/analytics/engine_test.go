package analytics

import (
	"bytes"
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/pitabwire/util"

	"github.com/antinvestor/service-thesa/model"
)

// recordingBackend is a MetricsBackend stub that records every query it
// receives and returns canned values.
type recordingBackend struct {
	calls   int
	queries []MetricQuery
	filters []TenantFilter
	value   float64
}

func (b *recordingBackend) record(query MetricQuery, filter TenantFilter) {
	b.calls++
	b.queries = append(b.queries, query)
	b.filters = append(b.filters, filter)
}

func (b *recordingBackend) QueryScalar(_ context.Context, query MetricQuery, filter TenantFilter, _ TimeRange) (float64, error) {
	b.record(query, filter)
	return b.value, nil
}

func (b *recordingBackend) QueryTimeSeries(_ context.Context, query MetricQuery, filter TenantFilter, _ TimeRange, _ time.Duration) ([]TimeSeriesPoint, error) {
	b.record(query, filter)
	return []TimeSeriesPoint{{Value: b.value}}, nil
}

func (b *recordingBackend) QueryGrouped(_ context.Context, query MetricQuery, filter TenantFilter, _ TimeRange, _ string) ([]LabelValue, error) {
	b.record(query, filter)
	return []LabelValue{{Label: "a", Value: b.value}}, nil
}

func (b *recordingBackend) QueryTopN(_ context.Context, query MetricQuery, filter TenantFilter, _ TimeRange, _ string, _ int) ([]LabelValue, error) {
	b.record(query, filter)
	return []LabelValue{{Label: "a", Value: b.value}}, nil
}

func (b *recordingBackend) Healthy(_ context.Context) error { return nil }

func newTestEngine(t *testing.T, backend MetricsBackend, opts ...EngineOption) *Engine {
	t.Helper()
	engine, err := NewEngine(backend, nil, opts...)
	if err != nil {
		t.Fatalf("NewEngine() error = %v", err)
	}
	return engine
}

func tenantContext(tenantID, partitionID string) context.Context {
	return model.WithRequestContext(context.Background(), &model.RequestContext{
		SubjectID:   "user-1",
		TenantID:    tenantID,
		PartitionID: partitionID,
	})
}

func testTimeRange() TimeRange {
	return TimeRange{
		Start: time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC),
		End:   time.Date(2026, 6, 8, 0, 0, 0, 0, time.UTC),
	}
}

func TestScalar_InjectsTenantAndPartitionScope(t *testing.T) {
	backend := &recordingBackend{value: 42}
	engine := newTestEngine(t, backend, WithCacheTTL(0))
	ctx := tenantContext("acme-corp", "part-01")

	val, err := engine.Scalar(ctx, MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum}, nil, testTimeRange())

	if err != nil {
		t.Fatalf("Scalar() error = %v", err)
	}
	if val != 42 {
		t.Errorf("Scalar() = %v, want 42", val)
	}
	if backend.calls != 1 {
		t.Fatalf("backend calls = %d, want 1", backend.calls)
	}
	filter := backend.filters[0]
	if !filter.Scoped {
		t.Error("filter.Scoped = false, want true: tenant scoping must be applied")
	}
	if filter.TenantID != "acme-corp" {
		t.Errorf("filter.TenantID = %q, want acme-corp", filter.TenantID)
	}
	if len(filter.PartitionIDs) != 1 || filter.PartitionIDs[0] != "part-01" {
		t.Errorf("filter.PartitionIDs = %v, want [part-01]", filter.PartitionIDs)
	}
}

func TestScalar_ClientTenantFiltersAreNeutralized(t *testing.T) {
	backend := &recordingBackend{value: 1}
	engine := newTestEngine(t, backend, WithCacheTTL(0))
	ctx := tenantContext("acme-corp", "part-01")

	query := MetricQuery{
		Metric:      "loans_disbursed_total",
		Aggregation: AggSum,
		Filters: map[string]string{
			"tenant_id":    "victim-tenant",
			"partition_id": "victim-partition",
			"tenant.id":    "victim-tenant-dotted",
			"status":       "approved",
		},
	}

	if _, err := engine.Scalar(ctx, query, nil, testTimeRange()); err != nil {
		t.Fatalf("Scalar() error = %v", err)
	}

	got := backend.queries[0].Filters
	for _, forbidden := range []string{"tenant_id", "partition_id", "tenant.id"} {
		if _, ok := got[forbidden]; ok {
			t.Errorf("client filter %q reached the backend; tenancy filters must be neutralized", forbidden)
		}
	}
	if got["status"] != "approved" {
		t.Errorf("legitimate filter dropped: Filters = %v", got)
	}
	if backend.filters[0].TenantID != "acme-corp" {
		t.Errorf("tenant scope = %q, want acme-corp (client filter must not override)", backend.filters[0].TenantID)
	}
}

func TestScalar_RatioQueryFiltersAreNeutralizedRecursively(t *testing.T) {
	backend := &recordingBackend{value: 1}
	engine := newTestEngine(t, backend, WithCacheTTL(0))
	ctx := tenantContext("acme-corp", "")

	query := MetricQuery{
		Numerator: &MetricQuery{
			Metric:  "loans_approved_total",
			Filters: map[string]string{"tenant_id": "victim"},
		},
		Denominator: &MetricQuery{
			Metric:  "loans_applications_total",
			Filters: map[string]string{"partition_id": "victim"},
		},
	}

	if _, err := engine.Scalar(ctx, query, nil, testTimeRange()); err != nil {
		t.Fatalf("Scalar() error = %v", err)
	}

	sent := backend.queries[0]
	if _, ok := sent.Numerator.Filters["tenant_id"]; ok {
		t.Error("numerator tenant_id filter reached the backend")
	}
	if _, ok := sent.Denominator.Filters["partition_id"]; ok {
		t.Error("denominator partition_id filter reached the backend")
	}
}

func TestScalar_MissingTenantClaimsRejected(t *testing.T) {
	backend := &recordingBackend{}
	engine := newTestEngine(t, backend, WithCacheTTL(0))

	tests := []struct {
		name string
		ctx  context.Context
	}{
		{name: "no request context", ctx: context.Background()},
		{name: "empty tenant claim", ctx: tenantContext("", "")},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := engine.Scalar(tc.ctx, MetricQuery{Metric: "loans_disbursed_total"}, nil, testTimeRange())

			if !errors.Is(err, ErrTenantScopeRequired) {
				t.Fatalf("Scalar() error = %v, want ErrTenantScopeRequired", err)
			}
			if !isForbiddenError(err) {
				t.Error("isForbiddenError() = false, want true (handler must map to 403)")
			}
			if backend.calls != 0 {
				t.Errorf("backend calls = %d, want 0: rejected queries must never reach the backend", backend.calls)
			}
		})
	}
}

func TestScalar_GlobalCapabilityBypassesScopeWithAuditLog(t *testing.T) {
	backend := &recordingBackend{value: 7}
	engine := newTestEngine(t, backend, WithCacheTTL(0))

	var logBuf bytes.Buffer
	ctx := context.Background()
	ctx = util.ContextWithLogger(ctx, util.NewLogger(ctx,
		util.WithLogOutput(&logBuf),
		util.WithLogFormat("json"),
		util.WithLogNoColor(true),
	))
	ctx = model.WithRequestContext(ctx, &model.RequestContext{SubjectID: "platform-admin-1"})
	ctx = model.WithCapabilities(ctx, model.CapabilitySet{GlobalViewCapability: true})

	val, err := engine.Scalar(ctx, MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum}, nil, testTimeRange())

	if err != nil {
		t.Fatalf("Scalar() error = %v, want nil (global capability must bypass tenant scope)", err)
	}
	if val != 7 {
		t.Errorf("Scalar() = %v, want 7", val)
	}
	if backend.filters[0].Scoped {
		t.Error("filter.Scoped = true, want false for a global query")
	}

	logged := logBuf.String()
	if !strings.Contains(logged, "unscoped global query authorized") {
		t.Errorf("audit log line missing; log output:\n%s", logged)
	}
	if !strings.Contains(logged, "platform-admin-1") {
		t.Errorf("audit log must record the subject; log output:\n%s", logged)
	}
}

func TestScalar_DisallowedMetricRejected(t *testing.T) {
	backend := &recordingBackend{}
	engine := newTestEngine(t, backend, WithCacheTTL(0))
	ctx := tenantContext("acme-corp", "part-01")

	tests := []struct {
		name   string
		metric string
	}{
		{name: "infrastructure metric", metric: "node_cpu_seconds_total"},
		{name: "go runtime metric", metric: "go_goroutines"},
		{name: "empty metric selects everything", metric: ""},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := engine.Scalar(ctx, MetricQuery{Metric: tc.metric}, nil, testTimeRange())

			if !errors.Is(err, ErrMetricNotAllowed) {
				t.Fatalf("Scalar(%q) error = %v, want ErrMetricNotAllowed", tc.metric, err)
			}
			if !isValidationError(err) {
				t.Error("isValidationError() = false, want true (handler must map to 400)")
			}
			if backend.calls != 0 {
				t.Errorf("backend calls = %d, want 0", backend.calls)
			}
		})
	}
}

func TestScalar_SecondIdenticalRequestServedFromCache(t *testing.T) {
	backend := &recordingBackend{value: 9}
	engine := newTestEngine(t, backend, WithCacheTTL(2*time.Minute))
	ctx := tenantContext("acme-corp", "part-01")
	query := MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum}

	first, err := engine.Scalar(ctx, query, nil, testTimeRange())
	if err != nil {
		t.Fatalf("first Scalar() error = %v", err)
	}
	second, err := engine.Scalar(ctx, query, nil, testTimeRange())
	if err != nil {
		t.Fatalf("second Scalar() error = %v", err)
	}

	if first != 9 || second != 9 {
		t.Errorf("Scalar() = %v / %v, want 9 / 9", first, second)
	}
	if backend.calls != 1 {
		t.Errorf("backend calls = %d, want 1: second identical request within TTL must be cached", backend.calls)
	}
}

func TestScalar_CacheIsolatedPerTenant(t *testing.T) {
	backend := &recordingBackend{value: 9}
	engine := newTestEngine(t, backend, WithCacheTTL(2*time.Minute))
	query := MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum}

	if _, err := engine.Scalar(tenantContext("tenant-a", "p1"), query, nil, testTimeRange()); err != nil {
		t.Fatalf("Scalar() error = %v", err)
	}
	if _, err := engine.Scalar(tenantContext("tenant-b", "p1"), query, nil, testTimeRange()); err != nil {
		t.Fatalf("Scalar() error = %v", err)
	}

	if backend.calls != 2 {
		t.Errorf("backend calls = %d, want 2: cache entries must be tenant-scoped", backend.calls)
	}
}

func TestScalar_CacheDisabledWithZeroTTL(t *testing.T) {
	backend := &recordingBackend{value: 9}
	engine := newTestEngine(t, backend, WithCacheTTL(0))
	ctx := tenantContext("acme-corp", "part-01")
	query := MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum}

	for i := 0; i < 2; i++ {
		if _, err := engine.Scalar(ctx, query, nil, testTimeRange()); err != nil {
			t.Fatalf("Scalar() error = %v", err)
		}
	}
	if backend.calls != 2 {
		t.Errorf("backend calls = %d, want 2 when caching is disabled", backend.calls)
	}
}

func TestNewEngine_InvalidAllowlistPatternFails(t *testing.T) {
	_, err := NewEngine(&recordingBackend{}, nil, WithAllowedMetrics([]string{"("}))
	if err == nil {
		t.Fatal("NewEngine() with invalid regex should return error")
	}
}

func TestMetricAllowlist_Defaults(t *testing.T) {
	allowlist, err := newMetricAllowlist(nil)
	if err != nil {
		t.Fatalf("newMetricAllowlist(defaults) error = %v", err)
	}

	tests := []struct {
		metric string
		want   bool
	}{
		{"loans_disbursed_total", true},
		{"payments_transactions_total", true},
		{"file_service_uploads_total", true},
		{"engine.commands.executed", true},
		{"queue.depth", true},
		{"devices/active_count", true},
		{"service_geolocation/points_recorded", true},
		{"profile/lookup/latency", true},
		{"contact/completed_calls", true},
		{"http.server.request.duration", true},
		{"db.client.operation.duration", true},
		{"rpc.client.duration", true},
		{"rpc.server.duration", true},
		{"gocloud.dev/pubsub/latency", true},
		{"node_cpu_seconds_total", false},
		{"go_goroutines", false},
		{"process_resident_memory_bytes", false},
		{"up", false},
		{"engine_underscore_not_dotted", false},
	}

	for _, tc := range tests {
		if got := allowlist.allows(tc.metric); got != tc.want {
			t.Errorf("allows(%q) = %v, want %v", tc.metric, got, tc.want)
		}
	}
}

// allowingResolver returns a fixed accessible-partition set, standing in for
// the hierarchical resolver.
type allowingResolver struct{ accessible []string }

func (r allowingResolver) ResolveAccessiblePartitions(_ context.Context, _ *model.RequestContext) ([]string, error) {
	return r.accessible, nil
}

func TestScalar_ExplicitPartitionsValidatedAgainstAccessibleSet(t *testing.T) {
	backend := &recordingBackend{value: 7}
	engine, err := NewEngine(backend, allowingResolver{accessible: []string{"part-01", "part-02"}}, WithCacheTTL(0))
	if err != nil {
		t.Fatalf("NewEngine() error = %v", err)
	}
	ctx := tenantContext("acme-corp", "part-01")

	// Accessible subset: the filter must carry exactly the supplied
	// partitions — the summation never widens beyond them.
	if _, err = engine.Scalar(ctx, MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum},
		[]string{"part-02"}, testTimeRange()); err != nil {
		t.Fatalf("Scalar(accessible partition) error = %v", err)
	}
	filter := backend.filters[0]
	if len(filter.PartitionIDs) != 1 || filter.PartitionIDs[0] != "part-02" {
		t.Errorf("filter.PartitionIDs = %v, want [part-02]", filter.PartitionIDs)
	}
	if filter.TenantID != "acme-corp" || !filter.Scoped {
		t.Errorf("filter = %+v, want scoped to acme-corp", filter)
	}

	// A partition outside the accessible set must be rejected outright —
	// never silently dropped or widened.
	_, err = engine.Scalar(ctx, MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum},
		[]string{"part-02", "part-99"}, testTimeRange())
	if err == nil || !strings.Contains(err.Error(), `"part-99" is not accessible`) {
		t.Fatalf("Scalar(inaccessible partition) error = %v, want not-accessible rejection", err)
	}
	if !isForbiddenError(err) {
		t.Errorf("isForbiddenError(%v) = false, want true (handlers must map to 403)", err)
	}
	if backend.calls != 1 {
		t.Errorf("backend calls = %d, want 1: rejected query must never reach the backend", backend.calls)
	}
}

func TestScalar_WildcardResolvesToAccessiblePartitionsOnly(t *testing.T) {
	backend := &recordingBackend{value: 7}
	engine, err := NewEngine(backend, allowingResolver{accessible: []string{"part-01", "part-02", "part-03"}}, WithCacheTTL(0))
	if err != nil {
		t.Fatalf("NewEngine() error = %v", err)
	}
	ctx := tenantContext("acme-corp", "part-01")

	if _, err = engine.Scalar(ctx, MetricQuery{Metric: "loans_disbursed_total", Aggregation: AggSum},
		[]string{"*"}, testTimeRange()); err != nil {
		t.Fatalf("Scalar(wildcard) error = %v", err)
	}

	filter := backend.filters[0]
	want := []string{"part-01", "part-02", "part-03"}
	if len(filter.PartitionIDs) != len(want) {
		t.Fatalf("filter.PartitionIDs = %v, want %v", filter.PartitionIDs, want)
	}
	for i, id := range want {
		if filter.PartitionIDs[i] != id {
			t.Errorf("filter.PartitionIDs[%d] = %q, want %q", i, filter.PartitionIDs[i], id)
		}
	}
}
