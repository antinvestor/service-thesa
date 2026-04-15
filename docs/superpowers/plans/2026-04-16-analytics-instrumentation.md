# Analytics Instrumentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add OTel business metric counters to 5 fintech services, refactor Thesa into a stateless analytics proxy, redesign Seed's lending dashboard, and add cluster resource monitoring to Thesa's dashboard.

**Architecture:** Fintech services emit OTel counters from business logic → OTLP → OpenObserve. Frontends send structured metric queries to Thesa (POST API). Thesa translates to PromQL, injects tenant scoping, and proxies to OpenObserve. No per-service query definitions in Thesa.

**Tech Stack:** Go (OTel SDK, Frame framework, ConnectRPC), Dart/Flutter (Riverpod, fl_chart, antinvestor_ui_core), Kubernetes (Gateway API HTTPRoute, ExternalSecrets)

**Spec:** `docs/superpowers/specs/2026-04-16-analytics-instrumentation-design.md`

---

## Phase 1: Thesa Generic Query API (service-thesa)

Independent of fintech instrumentation. Can be built and merged first.

### Task 1: Refactor MetricQuery as request schema and add partition_ids

**Files:**
- Modify: `service-thesa/pkg/analytics/registry.go`
- Modify: `service-thesa/pkg/analytics/backend.go`

The existing `MetricQuery` struct stays as the API request schema. Remove the service registry types. Add `PartitionIDs` to query requests.

- [ ] **Step 1: Strip registry types from registry.go**

Keep only: `Aggregation` constants, `MetricQuery` struct, `ValidateGranularity()`, `ValidateGroupBy()`. Remove: `MetricDefinition`, `TimeSeriesDefinition`, `DistributionDefinition`, `TopNDefinition`, `ServiceAnalytics`, `Registry` struct, `NewRegistry()`, `Register()`, `Get()`, `Services()`, `AllPermissions()`, `RegisterDefaultServices()`, `effectivePermission()`.

Rename file to `query.go` since it's no longer a registry.

- [ ] **Step 2: Add AnalyticsRequest struct to query.go**

```go
// AnalyticsRequest is the JSON body for all analytics query endpoints.
type AnalyticsRequest struct {
	Metric       string            `json:"metric,omitempty"`
	Aggregation  Aggregation       `json:"aggregation,omitempty"`
	Filters      map[string]string `json:"filters,omitempty"`
	GroupBy      string            `json:"group_by,omitempty"`
	PartitionIDs []string          `json:"partition_ids,omitempty"`
	Numerator    *MetricQuery      `json:"numerator,omitempty"`
	Denominator  *MetricQuery      `json:"denominator,omitempty"`
	Limit        int               `json:"limit,omitempty"`
	TimeRange    TimeRangeRequest  `json:"time_range"`
	Step         string            `json:"step,omitempty"`
}

// TimeRangeRequest is the JSON representation of a query time window.
type TimeRangeRequest struct {
	Start string `json:"start"`
	End   string `json:"end"`
}

// ToMetricQuery converts the request to the internal MetricQuery used by the backend.
func (r *AnalyticsRequest) ToMetricQuery() MetricQuery {
	if r.Numerator != nil && r.Denominator != nil {
		return MetricQuery{Numerator: r.Numerator, Denominator: r.Denominator}
	}
	return MetricQuery{
		Metric:      r.Metric,
		Aggregation: r.Aggregation,
		Filters:     r.Filters,
		GroupBy:     r.GroupBy,
	}
}
```

- [ ] **Step 3: Build and verify**

Run: `cd /home/j/code/antinvestor/service-thesa && go build ./...`
Expected: Compilation errors in engine.go and handler.go (they reference removed types) — that's fine, we fix those next.

- [ ] **Step 4: Commit**

```bash
git add pkg/analytics/query.go
git rm pkg/analytics/registry.go
git rm pkg/analytics/queries.go
git commit -m "refactor(analytics): strip service registry, keep MetricQuery as request schema"
```

---

### Task 2: Simplify Engine to stateless query proxy

**Files:**
- Modify: `service-thesa/pkg/analytics/engine.go`

Remove the registry dependency. Engine becomes a thin wrapper: resolve tenant filter, delegate to backend.

- [ ] **Step 1: Rewrite engine.go**

Remove: `Registry` field, all `Query*` methods that look up service definitions.
Keep: `PartitionResolver`, `TenantFilter` resolution, response types (`Metric`, `TimeSeries`, `TimeSeriesPoint`, `DistributionSegment`, `TopNItem`, `TimeRange`).

New Engine struct:
```go
type Engine struct {
	backend           MetricsBackend
	partitionResolver PartitionResolver
}

func NewEngine(backend MetricsBackend, resolver PartitionResolver) *Engine {
	if resolver == nil {
		resolver = DefaultPartitionResolver{}
	}
	return &Engine{backend: backend, partitionResolver: resolver}
}
```

New methods that accept `MetricQuery` directly (no registry lookup):
```go
func (e *Engine) Scalar(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange) (float64, error)
func (e *Engine) TimeSeries(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange, step time.Duration) ([]TimeSeriesPoint, error)
func (e *Engine) Grouped(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange, groupBy string) ([]DistributionSegment, error)
func (e *Engine) TopN(ctx context.Context, query MetricQuery, partitionIDs []string, tr TimeRange, groupBy string, limit int) ([]TopNItem, error)
func (e *Engine) Healthy(ctx context.Context) error
```

Each method:
1. Calls `e.resolveFilter(ctx, partitionIDs)` to build `TenantFilter`
2. Delegates to `e.backend.Query*(...)`
3. Maps `LabelValue` results to `DistributionSegment`/`TopNItem`

Add `resolveFilter` which handles the three partition modes:
```go
func (e *Engine) resolveFilter(ctx context.Context, partitionIDs []string) (TenantFilter, error) {
	rctx := model.RequestContextFrom(ctx)
	if rctx == nil {
		return TenantFilter{}, fmt.Errorf("missing request context")
	}

	var pids []string
	switch {
	case len(partitionIDs) == 0:
		pids = []string{rctx.PartitionID}
	case len(partitionIDs) == 1 && partitionIDs[0] == "*":
		resolved, err := e.partitionResolver.ResolveAccessiblePartitions(ctx, rctx)
		if err != nil {
			return TenantFilter{}, fmt.Errorf("resolve partitions: %w", err)
		}
		pids = resolved
	default:
		accessible, err := e.partitionResolver.ResolveAccessiblePartitions(ctx, rctx)
		if err != nil {
			return TenantFilter{}, fmt.Errorf("resolve partitions: %w", err)
		}
		accessSet := make(map[string]bool, len(accessible))
		for _, p := range accessible {
			accessSet[p] = true
		}
		for _, p := range partitionIDs {
			if !accessSet[p] {
				return TenantFilter{}, fmt.Errorf("partition %q not accessible", p)
			}
		}
		pids = partitionIDs
	}

	return TenantFilter{
		TenantID:     rctx.TenantID,
		PartitionIDs: pids,
		Scoped:       true,
	}, nil
}
```

- [ ] **Step 2: Build and verify**

Run: `cd /home/j/code/antinvestor/service-thesa && go build ./...`
Expected: Errors in handler.go and main.go (they reference old Engine API). Fixed next.

- [ ] **Step 3: Commit**

```bash
git add pkg/analytics/engine.go
git commit -m "refactor(analytics): simplify engine to stateless query proxy"
```

---

### Task 3: Replace handler with generic POST query endpoints

**Files:**
- Modify: `service-thesa/pkg/analytics/handler.go`

Replace the 5 GET endpoints with 4 POST endpoints.

- [ ] **Step 1: Rewrite handler.go**

New `RegisterRoutes` function:
```go
func RegisterRoutes(
	mux *http.ServeMux,
	engine *Engine,
	authMiddleware func(http.Handler) http.Handler,
	rctxFn func(*http.Request) *model.RequestContext,
) {
	wrap := func(h http.HandlerFunc) http.Handler {
		return authMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if rctx := rctxFn(r); rctx != nil {
				ctx := model.RequestContextTo(r.Context(), rctx)
				h.ServeHTTP(w, r.WithContext(ctx))
			} else {
				writeError(w, http.StatusUnauthorized, "missing request context")
			}
		}))
	}

	mux.Handle("POST /api/analytics/query/scalar", wrap(handleScalar(engine)))
	mux.Handle("POST /api/analytics/query/timeseries", wrap(handleTimeSeries(engine)))
	mux.Handle("POST /api/analytics/query/grouped", wrap(handleGrouped(engine)))
	mux.Handle("POST /api/analytics/query/topn", wrap(handleTopN(engine)))
}
```

Each handler: parse JSON body as `AnalyticsRequest`, parse time range, call the matching `engine.*()` method, write JSON response.

`handleScalar`:
```go
func handleScalar(engine *Engine) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req AnalyticsRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		tr, err := parseTimeRange(req.TimeRange)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		val, err := engine.Scalar(r.Context(), req.ToMetricQuery(), req.PartitionIDs, tr)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, map[string]any{"value": val})
	}
}
```

Similar pattern for `handleTimeSeries` (parses `step`, returns `{"points": [...]}`), `handleGrouped` (parses `group_by`, returns `{"segments": [...]}`), `handleTopN` (parses `group_by` + `limit`, returns `{"items": [...]}`).

Keep helper functions: `parseTimeRange`, `writeJSON`, `writeError`.

- [ ] **Step 2: Update router.go to match new RegisterRoutes signature**

The `RegisterRoutes` call in `service-thesa/pkg/transport/router.go` changes from passing `capsFn` to just `rctxFn` (capability checks removed since there's no per-service permission model):

```go
if deps.AnalyticsEngine != nil {
	rctxFn := func(r *http.Request) *model.RequestContext {
		return model.RequestContextFrom(r.Context())
	}
	analytics.RegisterRoutes(mux, deps.AnalyticsEngine, authChain, rctxFn)
}
```

- [ ] **Step 3: Update main.go Engine construction**

In `service-thesa/apps/default/cmd/bff/main.go`, the `NewEngine` call drops the registry parameter:

```go
analyticsEngine = analytics.NewEngine(metricsBackend, nil)
```

Remove the `analyticsReg` variable and `RegisterDefaultServices` call.

- [ ] **Step 4: Build and verify**

Run: `cd /home/j/code/antinvestor/service-thesa && go build ./...`
Expected: Clean build.

- [ ] **Step 5: Commit**

```bash
git add pkg/analytics/handler.go pkg/transport/router.go apps/default/cmd/bff/main.go
git commit -m "feat(analytics): replace registry endpoints with generic POST query API"
```

---

### Task 4: Add Thesa HTTPRoute in deployments

**Files:**
- Create: `deployments/manifests/namespaces/gateway/unified-api/thesa-api.yaml`
- Modify: `deployments/manifests/namespaces/gateway/unified-api/kustomization.yaml`

- [ ] **Step 1: Create HTTPRoute**

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: thesa-api
spec:
  parentRefs:
    - kind: Gateway
      name: default
      namespace: gateway
      sectionName: https
  hostnames:
    - "api.stawi.org"
    - "api.stawi.dev"
    - "api.stawi.im"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: "/thesa"
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: "/"
      backendRefs:
        - kind: Service
          name: service-thesa
          namespace: gateway
          port: 80
          weight: 1
```

- [ ] **Step 2: Add to kustomization.yaml**

Add `- thesa-api.yaml` to the resources list in `deployments/manifests/namespaces/gateway/unified-api/kustomization.yaml`.

- [ ] **Step 3: Commit**

```bash
cd /home/j/code/antinvestor/deployments
git add manifests/namespaces/gateway/unified-api/thesa-api.yaml manifests/namespaces/gateway/unified-api/kustomization.yaml
git commit -m "feat(gateway): add HTTPRoute for Thesa analytics API at /thesa"
```

---

## Phase 2: Fintech OTel Instrumentation (service-fintech)

Independent of Phase 1 (metrics start flowing to OpenObserve regardless of whether Thesa proxy is ready).

### Task 5: Loans service — metrics.go + business method instrumentation

**Files:**
- Create: `service-fintech/apps/loans/service/business/metrics.go`
- Modify: `service-fintech/apps/loans/service/business/loan_account.go` (or wherever Disburse, Repay, Default, Close, Restructure, WriteOff are)
- Modify: `service-fintech/apps/loans/service/business/repayment.go`

- [ ] **Step 1: Create metrics.go with 9 counters**

```go
package business

import (
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/metric"
)

var loansMeter = otel.Meter("service-loans")

var (
	LoansCreated, _         = loansMeter.Int64Counter("loans_created_total", metric.WithDescription("New loan accounts created"), metric.WithUnit("{loan}"))
	LoansDisbursed, _       = loansMeter.Int64Counter("loans_disbursed_total", metric.WithDescription("Loan disbursements completed"), metric.WithUnit("{loan}"))
	LoansDisbursedAmount, _ = loansMeter.Float64Counter("loans_disbursed_amount_total", metric.WithDescription("Total amount disbursed"), metric.WithUnit("{currency}"))
	LoansRepaid, _          = loansMeter.Int64Counter("loans_repaid_total", metric.WithDescription("Repayments processed"), metric.WithUnit("{repayment}"))
	LoansRepaidAmount, _    = loansMeter.Float64Counter("loans_repaid_amount_total", metric.WithDescription("Total amount repaid"), metric.WithUnit("{currency}"))
	LoansDefaulted, _       = loansMeter.Int64Counter("loans_defaulted_total", metric.WithDescription("Loans marked as defaulted"), metric.WithUnit("{loan}"))
	LoansClosed, _          = loansMeter.Int64Counter("loans_closed_total", metric.WithDescription("Loans fully closed/paid off"), metric.WithUnit("{loan}"))
	LoansRestructured, _    = loansMeter.Int64Counter("loans_restructured_total", metric.WithDescription("Loans restructured"), metric.WithUnit("{loan}"))
	LoansWrittenOff, _      = loansMeter.Int64Counter("loans_written_off_total", metric.WithDescription("Loans written off"), metric.WithUnit("{loan}"))
)

type MetricInfo struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Unit        string `json:"unit"`
	Description string `json:"description"`
}

func RegisteredMetrics() []MetricInfo {
	return []MetricInfo{
		{Name: "loans_created_total", Type: "counter", Unit: "count", Description: "New loan accounts created"},
		{Name: "loans_disbursed_total", Type: "counter", Unit: "count", Description: "Loan disbursements completed"},
		{Name: "loans_disbursed_amount_total", Type: "counter", Unit: "currency", Description: "Total amount disbursed"},
		{Name: "loans_repaid_total", Type: "counter", Unit: "count", Description: "Repayments processed"},
		{Name: "loans_repaid_amount_total", Type: "counter", Unit: "currency", Description: "Total amount repaid"},
		{Name: "loans_defaulted_total", Type: "counter", Unit: "count", Description: "Loans marked as defaulted"},
		{Name: "loans_closed_total", Type: "counter", Unit: "count", Description: "Loans fully closed/paid off"},
		{Name: "loans_restructured_total", Type: "counter", Unit: "count", Description: "Loans restructured"},
		{Name: "loans_written_off_total", Type: "counter", Unit: "count", Description: "Loans written off"},
	}
}
```

- [ ] **Step 2: Add counter.Add() calls to business methods**

Find each business method that handles a loan lifecycle event. At the success point (after the database write succeeds), add the counter call. Extract `tenant_id` and `partition_id` from the request context using the pattern already in the codebase (check how audit or auth extracts these — likely via `frame.TenantIDFromContext(ctx)` or the model's request context).

Pattern for each call site:
```go
import "go.opentelemetry.io/otel/attribute"

// After successful disbursement:
LoansDisbursed.Add(ctx, 1, metric.WithAttributes(
	attribute.String("tenant_id", tenantID),
	attribute.String("partition_id", partitionID),
	attribute.String("currency", loan.CurrencyCode),
))
LoansDisbursedAmount.Add(ctx, float64(loan.DisbursedAmount)/100, metric.WithAttributes(
	attribute.String("tenant_id", tenantID),
	attribute.String("partition_id", partitionID),
	attribute.String("currency", loan.CurrencyCode),
))
```

Repeat for: Create, Repay (count + amount), Default, Close, Restructure, WriteOff.

- [ ] **Step 3: Build and verify**

Run: `cd /home/j/code/antinvestor/service-fintech && go build ./apps/loans/...`
Expected: Clean build.

- [ ] **Step 4: Commit**

```bash
git add apps/loans/service/business/metrics.go apps/loans/service/business/*.go
git commit -m "feat(loans): add OTel counter instrumentation for loan lifecycle events"
```

---

### Task 6: Funding service — metrics.go + instrumentation

**Files:**
- Create: `service-fintech/apps/funding/service/business/metrics.go`
- Modify: business methods for deposit, withdraw, allocate

- [ ] **Step 1: Create metrics.go with 6 counters**

```go
package business

import (
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/metric"
)

var fundingMeter = otel.Meter("service-funding")

var (
	FundingDeposits, _          = fundingMeter.Int64Counter("funding_deposits_total", metric.WithDescription("Investor deposits"), metric.WithUnit("{deposit}"))
	FundingDepositsAmount, _    = fundingMeter.Float64Counter("funding_deposits_amount_total", metric.WithDescription("Total investor deposit amount"), metric.WithUnit("{currency}"))
	FundingWithdrawals, _       = fundingMeter.Int64Counter("funding_withdrawals_total", metric.WithDescription("Investor withdrawals"), metric.WithUnit("{withdrawal}"))
	FundingWithdrawalsAmount, _ = fundingMeter.Float64Counter("funding_withdrawals_amount_total", metric.WithDescription("Total investor withdrawal amount"), metric.WithUnit("{currency}"))
	FundingAllocations, _       = fundingMeter.Int64Counter("funding_allocations_total", metric.WithDescription("Loan funding allocations"), metric.WithUnit("{allocation}"))
	FundingAllocationsAmount, _ = fundingMeter.Float64Counter("funding_allocations_amount_total", metric.WithDescription("Total allocated to loans"), metric.WithUnit("{currency}"))
)

type MetricInfo struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Unit        string `json:"unit"`
	Description string `json:"description"`
}

func RegisteredMetrics() []MetricInfo {
	return []MetricInfo{
		{Name: "funding_deposits_total", Type: "counter", Unit: "count", Description: "Investor deposits"},
		{Name: "funding_deposits_amount_total", Type: "counter", Unit: "currency", Description: "Total investor deposit amount"},
		{Name: "funding_withdrawals_total", Type: "counter", Unit: "count", Description: "Investor withdrawals"},
		{Name: "funding_withdrawals_amount_total", Type: "counter", Unit: "currency", Description: "Total investor withdrawal amount"},
		{Name: "funding_allocations_total", Type: "counter", Unit: "count", Description: "Loan funding allocations"},
		{Name: "funding_allocations_amount_total", Type: "counter", Unit: "currency", Description: "Total allocated to loans"},
	}
}
```

- [ ] **Step 2: Add counter.Add() calls to funding business methods**

Same pattern as Task 5 Step 2: find deposit, withdrawal, and allocation success points, add counter increments with tenant_id, partition_id, currency attributes.

- [ ] **Step 3: Build and verify**

Run: `cd /home/j/code/antinvestor/service-fintech && go build ./apps/funding/...`

- [ ] **Step 4: Commit**

```bash
git add apps/funding/service/business/metrics.go apps/funding/service/business/*.go
git commit -m "feat(funding): add OTel counter instrumentation for investor operations"
```

---

### Task 7: Savings service — metrics.go + instrumentation

**Files:**
- Create: `service-fintech/apps/savings/service/business/metrics.go`
- Modify: business methods for account open, deposit, withdraw, interest accrual

- [ ] **Step 1: Create metrics.go with 6 counters**

```go
package business

import (
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/metric"
)

var savingsMeter = otel.Meter("service-savings")

var (
	SavingsAccountsOpened, _       = savingsMeter.Int64Counter("savings_accounts_opened_total", metric.WithDescription("New savings accounts"), metric.WithUnit("{account}"))
	SavingsDeposits, _             = savingsMeter.Int64Counter("savings_deposits_total", metric.WithDescription("Savings deposits"), metric.WithUnit("{deposit}"))
	SavingsDepositsAmount, _       = savingsMeter.Float64Counter("savings_deposits_amount_total", metric.WithDescription("Total savings deposited"), metric.WithUnit("{currency}"))
	SavingsWithdrawals, _          = savingsMeter.Int64Counter("savings_withdrawals_total", metric.WithDescription("Savings withdrawals"), metric.WithUnit("{withdrawal}"))
	SavingsWithdrawalsAmount, _    = savingsMeter.Float64Counter("savings_withdrawals_amount_total", metric.WithDescription("Total savings withdrawn"), metric.WithUnit("{currency}"))
	SavingsInterestAccrued, _      = savingsMeter.Float64Counter("savings_interest_accrued_amount_total", metric.WithDescription("Total interest accrued"), metric.WithUnit("{currency}"))
)

type MetricInfo struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Unit        string `json:"unit"`
	Description string `json:"description"`
}

func RegisteredMetrics() []MetricInfo {
	return []MetricInfo{
		{Name: "savings_accounts_opened_total", Type: "counter", Unit: "count", Description: "New savings accounts"},
		{Name: "savings_deposits_total", Type: "counter", Unit: "count", Description: "Savings deposits"},
		{Name: "savings_deposits_amount_total", Type: "counter", Unit: "currency", Description: "Total savings deposited"},
		{Name: "savings_withdrawals_total", Type: "counter", Unit: "count", Description: "Savings withdrawals"},
		{Name: "savings_withdrawals_amount_total", Type: "counter", Unit: "currency", Description: "Total savings withdrawn"},
		{Name: "savings_interest_accrued_amount_total", Type: "counter", Unit: "currency", Description: "Total interest accrued"},
	}
}
```

- [ ] **Step 2: Add counter.Add() calls to savings business methods**

- [ ] **Step 3: Build and verify**

Run: `cd /home/j/code/antinvestor/service-fintech && go build ./apps/savings/...`

- [ ] **Step 4: Commit**

```bash
git add apps/savings/service/business/metrics.go apps/savings/service/business/*.go
git commit -m "feat(savings): add OTel counter instrumentation for savings operations"
```

---

### Task 8: Operations service — metrics.go + instrumentation

**Files:**
- Create: `service-fintech/apps/operations/service/business/metrics.go`
- Modify: business methods for transfers, payments received, allocation

- [ ] **Step 1: Create metrics.go with 6 counters**

```go
package business

import (
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/metric"
)

var opsMeter = otel.Meter("service-operations")

var (
	OpsTransfersExecuted, _  = opsMeter.Int64Counter("ops_transfers_executed_total", metric.WithDescription("Transfer orders executed"), metric.WithUnit("{transfer}"))
	OpsTransfersAmount, _    = opsMeter.Float64Counter("ops_transfers_amount_total", metric.WithDescription("Total transfer amount"), metric.WithUnit("{currency}"))
	OpsPaymentsReceived, _   = opsMeter.Int64Counter("ops_payments_received_total", metric.WithDescription("Incoming payments received"), metric.WithUnit("{payment}"))
	OpsPaymentsAmount, _     = opsMeter.Float64Counter("ops_payments_amount_total", metric.WithDescription("Total incoming payment amount"), metric.WithUnit("{currency}"))
	OpsPaymentsAllocated, _  = opsMeter.Int64Counter("ops_payments_allocated_total", metric.WithDescription("Payments successfully allocated"), metric.WithUnit("{payment}"))
	OpsPaymentsUnmatched, _  = opsMeter.Int64Counter("ops_payments_unmatched_total", metric.WithDescription("Payments that could not be matched"), metric.WithUnit("{payment}"))
)

type MetricInfo struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Unit        string `json:"unit"`
	Description string `json:"description"`
}

func RegisteredMetrics() []MetricInfo {
	return []MetricInfo{
		{Name: "ops_transfers_executed_total", Type: "counter", Unit: "count", Description: "Transfer orders executed"},
		{Name: "ops_transfers_amount_total", Type: "counter", Unit: "currency", Description: "Total transfer amount"},
		{Name: "ops_payments_received_total", Type: "counter", Unit: "count", Description: "Incoming payments received"},
		{Name: "ops_payments_amount_total", Type: "counter", Unit: "currency", Description: "Total incoming payment amount"},
		{Name: "ops_payments_allocated_total", Type: "counter", Unit: "count", Description: "Payments successfully allocated"},
		{Name: "ops_payments_unmatched_total", Type: "counter", Unit: "count", Description: "Payments that could not be matched"},
	}
}
```

- [ ] **Step 2: Add counter.Add() calls to operations business methods**

- [ ] **Step 3: Build and verify**

Run: `cd /home/j/code/antinvestor/service-fintech && go build ./apps/operations/...`

- [ ] **Step 4: Commit**

```bash
git add apps/operations/service/business/metrics.go apps/operations/service/business/*.go
git commit -m "feat(operations): add OTel counter instrumentation for payment operations"
```

---

### Task 9: Identity service — metrics.go + instrumentation

**Files:**
- Create: `service-fintech/apps/identity/service/business/metrics.go`
- Modify: business methods for org creation, org unit creation, workforce add/remove

- [ ] **Step 1: Create metrics.go with 4 counters**

```go
package business

import (
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/metric"
)

var identityMeter = otel.Meter("service-identity")

var (
	IdentityOrgsCreated, _      = identityMeter.Int64Counter("identity_organizations_created_total", metric.WithDescription("New organizations registered"), metric.WithUnit("{organization}"))
	IdentityOrgUnitsCreated, _  = identityMeter.Int64Counter("identity_org_units_created_total", metric.WithDescription("New org units created"), metric.WithUnit("{org_unit}"))
	IdentityWorkforceAdded, _   = identityMeter.Int64Counter("identity_workforce_added_total", metric.WithDescription("Workforce members added"), metric.WithUnit("{member}"))
	IdentityWorkforceRemoved, _ = identityMeter.Int64Counter("identity_workforce_removed_total", metric.WithDescription("Workforce members removed"), metric.WithUnit("{member}"))
)

type MetricInfo struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Unit        string `json:"unit"`
	Description string `json:"description"`
}

func RegisteredMetrics() []MetricInfo {
	return []MetricInfo{
		{Name: "identity_organizations_created_total", Type: "counter", Unit: "count", Description: "New organizations registered"},
		{Name: "identity_org_units_created_total", Type: "counter", Unit: "count", Description: "New org units created"},
		{Name: "identity_workforce_added_total", Type: "counter", Unit: "count", Description: "Workforce members added"},
		{Name: "identity_workforce_removed_total", Type: "counter", Unit: "count", Description: "Workforce members removed"},
	}
}
```

- [ ] **Step 2: Add counter.Add() calls to identity business methods**

- [ ] **Step 3: Build and verify**

Run: `cd /home/j/code/antinvestor/service-fintech && go build ./apps/identity/...`

- [ ] **Step 4: Commit**

```bash
git add apps/identity/service/business/metrics.go apps/identity/service/business/*.go
git commit -m "feat(identity): add OTel counter instrumentation for org and workforce events"
```

---

## Phase 3: Seed Dashboard (service-fintech/ui/seed)

Depends on Phase 1 (Thesa API). Can be built in parallel if the analytics client is updated first.

### Task 10: Update analytics client for POST query API

**Files:**
- Modify: `service-fintech/ui/seed/lib/core/data/analytics_client.dart`
- Modify: `service-fintech/ui/seed/lib/core/config/app_config.dart`
- Modify: `service-fintech/ui/seed/lib/main.dart`

- [ ] **Step 1: Add thesaBaseUrl to AppConfig**

In `app_config.dart`, add:
```dart
static String get thesaBaseUrl => _envOr('THESA_BASE_URL', '$_apiBaseUrl/thesa');
```

- [ ] **Step 2: Rewrite analytics_client.dart for POST query API**

Replace the GET-based client with one that sends POST requests matching Thesa's new API:

```dart
class RestAnalyticsDataSource implements AnalyticsDataSource {
  RestAnalyticsDataSource(this._httpClient, this._baseUrl);

  final http.Client _httpClient;
  final String _baseUrl;

  Future<double> queryScalar({
    String? metric,
    String aggregation = 'sum',
    Map<String, String>? filters,
    List<String>? partitionIds,
    Map<String, dynamic>? numerator,
    Map<String, dynamic>? denominator,
    required AnalyticsTimeRange timeRange,
  }) async {
    final body = <String, dynamic>{
      if (metric != null) 'metric': metric,
      'aggregation': aggregation,
      if (filters != null) 'filters': filters,
      if (partitionIds != null) 'partition_ids': partitionIds,
      if (numerator != null) 'numerator': numerator,
      if (denominator != null) 'denominator': denominator,
      'time_range': _timeRangeJson(timeRange),
    };
    final resp = await _post('/api/analytics/query/scalar', body);
    return (resp['value'] as num?)?.toDouble() ?? 0;
  }

  Future<List<TimeSeriesPoint>> queryTimeSeries({
    required String metric,
    String aggregation = 'sum',
    Map<String, String>? filters,
    List<String>? partitionIds,
    required AnalyticsTimeRange timeRange,
    String step = '1d',
  }) async {
    final body = <String, dynamic>{
      'metric': metric,
      'aggregation': aggregation,
      if (filters != null) 'filters': filters,
      if (partitionIds != null) 'partition_ids': partitionIds,
      'time_range': _timeRangeJson(timeRange),
      'step': step,
    };
    final resp = await _post('/api/analytics/query/timeseries', body);
    final points = resp['points'] as List<dynamic>? ?? [];
    return points.map((p) {
      final m = p as Map<String, dynamic>;
      return TimeSeriesPoint(
        timestamp: DateTime.parse(m['timestamp'] as String),
        value: (m['value'] as num).toDouble(),
      );
    }).toList();
  }

  Future<List<DistributionSegment>> queryGrouped({
    required String metric,
    String aggregation = 'sum',
    required String groupBy,
    Map<String, String>? filters,
    List<String>? partitionIds,
    required AnalyticsTimeRange timeRange,
  }) async {
    final body = <String, dynamic>{
      'metric': metric,
      'aggregation': aggregation,
      'group_by': groupBy,
      if (filters != null) 'filters': filters,
      if (partitionIds != null) 'partition_ids': partitionIds,
      'time_range': _timeRangeJson(timeRange),
    };
    final resp = await _post('/api/analytics/query/grouped', body);
    final segments = resp['segments'] as List<dynamic>? ?? [];
    return segments.map((s) {
      final m = s as Map<String, dynamic>;
      return DistributionSegment(
        label: m['label'] as String,
        value: (m['value'] as num).toDouble(),
      );
    }).toList();
  }

  Map<String, String> _timeRangeJson(AnalyticsTimeRange tr) => {
    'start': tr.start.toUtc().toIso8601String(),
    'end': tr.end.toUtc().toIso8601String(),
  };

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Analytics API error: HTTP ${response.statusCode}');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }
}
```

Note: This client no longer implements `AnalyticsDataSource` from ui_core (which expected the old GET-based service-keyed API). It exposes query-level methods that the dashboard calls directly.

- [ ] **Step 3: Update main.dart provider override**

Change the analytics provider to point at Thesa:
```dart
analyticsDataSourceProvider.overrideWith((ref) {
  return RestAnalyticsDataSource(
    http.Client(),
    AppConfig.thesaBaseUrl,
  );
}),
```

- [ ] **Step 4: Verify flutter analyze**

Run: `cd /home/j/code/antinvestor/service-fintech/ui/seed && flutter analyze`
Expected: Errors in dashboard_screen.dart (it still uses the old AnalyticsDashboard widget). Fixed in next task.

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/analytics_client.dart lib/core/config/app_config.dart lib/main.dart
git commit -m "feat(seed): update analytics client for Thesa POST query API"
```

---

### Task 11: Redesign Seed dashboard for lending KPIs

**Files:**
- Modify: `service-fintech/ui/seed/lib/features/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Rewrite dashboard_screen.dart**

Replace the `AnalyticsDashboard` widget with a custom `ConsumerStatefulWidget` that calls the `RestAnalyticsDataSource` query methods directly. The dashboard has 4 rows:

1. **Business health KPIs** — 4 cards showing Total Customers, Active Loans (derived), Portfolio Value (derived), Default Rate (ratio)
2. **Today's snapshot** — 4 cards with today's time range for Loans Disbursed, Amount Disbursed, Amount Repaid, Defaults
3. **Trend charts** — Customer Growth line chart + Portfolio Growth line chart (using fl_chart)
4. **Org unit proportions** — Pie chart with `queryGrouped(groupBy: "partition_id", partitionIds: ["*"])`

The widget:
- Has a `_timeRange` state variable controlled by a `TimeRangeSelector`
- Fetches all queries in `initState` / on time range change
- Uses `FutureBuilder` or `AsyncSnapshot` pattern for each data section
- Today's snapshot always uses `AnalyticsTimeRange(start: today 00:00, end: now)`
- Formats currency values with `NumberFormat.compactCurrency()`
- Shows loading spinners during fetch, error messages on failure

The derived metrics (Active Loans, Portfolio Value) require multiple scalar queries:
```dart
final created = await analytics.queryScalar(metric: 'loans_created_total', ...);
final closed = await analytics.queryScalar(metric: 'loans_closed_total', ...);
final defaulted = await analytics.queryScalar(metric: 'loans_defaulted_total', ...);
final writtenOff = await analytics.queryScalar(metric: 'loans_written_off_total', ...);
final activeLoans = created - closed - defaulted - writtenOff;
```

- [ ] **Step 2: Verify flutter analyze**

Run: `cd /home/j/code/antinvestor/service-fintech/ui/seed && flutter analyze`
Expected: No issues.

- [ ] **Step 3: Build web**

Run: `cd /home/j/code/antinvestor/service-fintech/ui/seed && flutter build web --no-tree-shake-icons`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dashboard/dashboard_screen.dart
git commit -m "feat(seed): redesign dashboard with lending KPIs, trends, and org unit proportions"
```

---

## Phase 4: Thesa Dashboard Migration (service-thesa/ui)

### Task 12: Update Thesa analytics client for POST query API

**Files:**
- Modify: `service-thesa/ui/lib/core/services/analytics_client.dart`

- [ ] **Step 1: Rewrite analytics_client.dart**

Same pattern as Task 10 Step 2 — replace GET-based `ThesaAnalyticsDataSource` with POST query methods. Since Thesa UI talks to its own backend, the base URL stays the same (just the endpoints change from GET to POST).

- [ ] **Step 2: Commit**

```bash
git add ui/lib/core/services/analytics_client.dart
git commit -m "feat(ui): update Thesa analytics client for POST query API"
```

---

### Task 13: Redesign Thesa dashboard with cluster metrics

**Files:**
- Modify: `service-thesa/ui/lib/features/dashboard/dashboard_page.dart`
- Modify: `service-thesa/ui/lib/features/dashboard/widgets/portfolio_chart.dart`
- Modify: `service-thesa/ui/lib/features/dashboard/widgets/asset_distribution.dart`
- Modify: `service-thesa/ui/lib/features/dashboard/widgets/regional_performance.dart`

- [ ] **Step 1: Rewrite dashboard_page.dart**

Replace the current payment-focused dashboard with cluster-wide metrics:
- Row 1: KPI cards — Total API Requests (`rpc.server.duration` count), Error Rate (ratio), Active Tenants, Notifications Sent
- Row 2: Traffic charts — API Traffic Over Time, Payment Volume
- Row 3: Traffic by Service distribution pie chart
- Row 4: Cluster Resources — CPU, Memory, Disk per service

Each section calls the `RestAnalyticsDataSource` query methods with the appropriate metric names and aggregations.

- [ ] **Step 2: Update widget files**

Rename/repurpose:
- `portfolio_chart.dart` → API Traffic Over Time (time series of `rpc.server.duration` count)
- `asset_distribution.dart` → Traffic by Service (pie chart of `rpc.server.duration` grouped by `rpc.service`)
- `regional_performance.dart` → Cluster Resources (progress bars for CPU/memory/disk per service)

- [ ] **Step 3: Verify flutter analyze and build**

Run: `cd /home/j/code/antinvestor/service-thesa/ui && flutter analyze && flutter build web --no-tree-shake-icons`
Expected: Clean analyze, successful build.

- [ ] **Step 4: Commit**

```bash
git add ui/lib/features/dashboard/ ui/lib/core/services/analytics_client.dart
git commit -m "feat(ui): redesign Thesa dashboard with cluster metrics and resource monitoring"
```

---

### Task 14: Update Thesa analytics page

**Files:**
- Modify: `service-thesa/ui/lib/features/analytics/analytics_page.dart`

- [ ] **Step 1: Update analytics page**

The analytics page currently uses the `AnalyticsDashboard` widget with service-specific configs. Since the old GET API is removed, replace it with a page that lets users query metrics directly — a simple form with metric name, aggregation, time range, and group_by fields, plus a chart area that renders results.

Alternatively, if this page is not critical for the initial release, it can be simplified to show the same content as the dashboard in a different layout, or removed entirely and added back later.

- [ ] **Step 2: Verify flutter analyze**

Run: `cd /home/j/code/antinvestor/service-thesa/ui && flutter analyze`

- [ ] **Step 3: Commit**

```bash
git add ui/lib/features/analytics/analytics_page.dart
git commit -m "feat(ui): update analytics page for POST query API"
```

---

## Phase 5: Integration PRs

### Task 15: Create PRs for all repos

- [ ] **Step 1: service-thesa PR**

```bash
cd /home/j/code/antinvestor/service-thesa
git push -u origin feat/analytics-generic-proxy
gh pr create --title "feat(analytics): stateless query proxy API" --body "..."
```

- [ ] **Step 2: service-fintech PR**

```bash
cd /home/j/code/antinvestor/service-fintech
git push -u origin feat/otel-instrumentation
gh pr create --title "feat: OTel counter instrumentation + Seed lending dashboard" --body "..."
```

- [ ] **Step 3: deployments PR**

```bash
cd /home/j/code/antinvestor/deployments
git push -u origin feat/thesa-httproute
gh pr create --title "feat(gateway): add Thesa HTTPRoute at /thesa" --body "..."
```
