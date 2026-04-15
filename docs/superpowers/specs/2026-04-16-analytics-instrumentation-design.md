# Analytics Instrumentation & Dashboard Design

## Overview

Add OTel business metric instrumentation across 5 fintech services, refactor Thesa into a stateless analytics proxy, redesign the Seed lending dashboard, and add cluster resource monitoring to the Thesa dashboard.

## Architecture

```
Seed UI / Thesa UI (frontends)
  Each defines its own dashboard config:
  metric names, aggregations, filters, time ranges
      │ POST api.stawi.org/thesa/api/analytics/query/*
      ▼
Thesa BFF (service-thesa)
  Stateless analytics proxy:
  - Authenticates request (JWT)
  - Injects tenant_id scoping
  - Validates partition_ids against user's accessible set
  - Translates structured query → PromQL
  - Forwards to OpenObserve, returns results
      │ PromQL via Prometheus-compat API
      ▼
OpenObserve (observe.stawi.org)
  Stores all OTel metrics from all services
      ▲ OTLP push
      │
Fintech Services (service-fintech)
  Business layer emits OTel counters on events
  Each service has a metric registry for discoverability
```

Key principle: Thesa is a **stateless proxy**. It has no per-service query definitions. The frontend sends structured metric queries; Thesa translates to PromQL, enforces tenant scoping, and forwards to OpenObserve. Adding new dashboard metrics is a frontend-only change.

## Thesa Generic Query API

### Endpoints

All endpoints use POST. Thesa injects `tenant_id` from JWT context as a mandatory label matcher on every query.

#### POST /api/analytics/query/scalar

Returns a single numeric value.

Request:
```json
{
  "metric": "loans_disbursed_amount_total",
  "aggregation": "sum",
  "filters": {"currency": "KES"},
  "partition_ids": ["branch-nairobi-cbd", "branch-westlands"],
  "time_range": {"start": "2026-04-01T00:00:00Z", "end": "2026-04-16T00:00:00Z"},
  "numerator": null,
  "denominator": null
}
```

Response:
```json
{"value": 1234567.89}
```

#### POST /api/analytics/query/timeseries

Returns time-bucketed values.

Request:
```json
{
  "metric": "loans_disbursed_total",
  "aggregation": "sum",
  "filters": {},
  "partition_ids": [],
  "time_range": {"start": "...", "end": "..."},
  "step": "1d"
}
```

Response:
```json
{"points": [{"timestamp": "2026-04-01T00:00:00Z", "value": 42}, ...]}
```

#### POST /api/analytics/query/grouped

Returns label-value pairs grouped by a dimension.

Request:
```json
{
  "metric": "loans_disbursed_amount_total",
  "aggregation": "sum",
  "filters": {},
  "partition_ids": ["*"],
  "group_by": "partition_id",
  "time_range": {"start": "...", "end": "..."}
}
```

Response:
```json
{"segments": [{"label": "branch-nairobi-cbd", "value": 500000}, ...]}
```

#### POST /api/analytics/query/topn

Returns ranked items.

Request:
```json
{
  "metric": "loans_disbursed_amount_total",
  "aggregation": "sum",
  "filters": {},
  "partition_ids": ["*"],
  "group_by": "partition_id",
  "limit": 10,
  "time_range": {"start": "...", "end": "..."}
}
```

Response:
```json
{"items": [{"label": "branch-nairobi-cbd", "value": 500000}, ...]}
```

### Partition ID handling

- **Omitted or empty**: Thesa uses the user's current partition from request context.
- **`["*"]`**: Thesa resolves all partitions the user has access to via `PartitionResolver`.
- **Explicit list**: Thesa validates each ID is in the user's accessible set. Rejects with 403 if any are unauthorized.

### Ratio queries

For derived metrics like default rate, the frontend sends numerator and denominator as nested query objects:

```json
{
  "numerator": {"metric": "loans_defaulted_total", "aggregation": "sum"},
  "denominator": {"metric": "loans_created_total", "aggregation": "sum"},
  "time_range": {"start": "...", "end": "..."}
}
```

Thesa generates: `(sum(increase(loans_defaulted_total{...}[range]))) / (sum(increase(loans_created_total{...}[range]))) * 100`

### What stays from current implementation

- `MetricQuery` struct (becomes the request body schema)
- `PrometheusBackend` / `OpenObserveBackend` (unchanged)
- `TenantFilter` and partition resolution (unchanged)
- PromQL generation functions (unchanged)

### What gets removed

- `Registry`, `ServiceAnalytics`, `MetricDefinition`, `TimeSeriesDefinition`, `DistributionDefinition`, `TopNDefinition`
- `queries.go` (hardcoded service definitions)
- `GET /api/analytics/services`, `/metrics`, `/timeseries`, `/distribution`, `/top` endpoints
- `handler.go` per-service lookup and permission filtering logic

## OTel Counter Instrumentation

### Approach

Pure counters — no gauges, no periodic jobs. Counters increment in the business layer at the point of the event. If counter drift becomes a problem, gauge snapshots can be added later. Dashboards show directional summaries; reports provide actual figures from the database.

### Pattern

Each service's business package gets a `metrics.go` file:

```go
package business

import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/metric"
)

var meter = otel.Meter("service-loans")

var (
    LoansDisbursed, _       = meter.Int64Counter("loans_disbursed_total",
        metric.WithDescription("Total loan disbursements"),
        metric.WithUnit("{loan}"))
    LoansDisbursedAmount, _ = meter.Float64Counter("loans_disbursed_amount_total",
        metric.WithDescription("Total amount disbursed"),
        metric.WithUnit("{currency}"))
    // ...
)

type MetricInfo struct {
    Name        string
    Type        string
    Unit        string
    Description string
}

func RegisteredMetrics() []MetricInfo {
    return []MetricInfo{
        {Name: "loans_disbursed_total", Type: "counter", Unit: "count", Description: "Total loan disbursements"},
        {Name: "loans_disbursed_amount_total", Type: "counter", Unit: "currency", Description: "Total amount disbursed"},
        // ...
    }
}
```

Usage in business methods:

```go
func (b *LoanBusiness) Disburse(ctx context.Context, loan *Loan) error {
    // ... existing disbursement logic ...

    attrs := metric.WithAttributes(
        attribute.String("tenant_id", tenantID),
        attribute.String("partition_id", partitionID),
        attribute.String("currency", loan.Currency),
    )
    LoansDisbursed.Add(ctx, 1, attrs)
    LoansDisbursedAmount.Add(ctx, float64(loan.Amount)/100, attrs)
    return nil
}
```

### Labels on every counter

- `tenant_id` — from request context (mandatory, for multi-tenant isolation)
- `partition_id` — from request context (mandatory, maps to branch/org unit)
- Service-specific dimensions where useful (e.g., `currency`, `status`, `channel`)

### Counters per service

#### Loans (9 counters)

| Metric name | Type | Unit | Description |
|---|---|---|---|
| `loans_created_total` | counter | count | New loan accounts created |
| `loans_disbursed_total` | counter | count | Loan disbursements completed |
| `loans_disbursed_amount_total` | counter | currency | Total amount disbursed |
| `loans_repaid_total` | counter | count | Repayments processed |
| `loans_repaid_amount_total` | counter | currency | Total amount repaid |
| `loans_defaulted_total` | counter | count | Loans marked as defaulted |
| `loans_closed_total` | counter | count | Loans fully closed/paid off |
| `loans_restructured_total` | counter | count | Loans restructured |
| `loans_written_off_total` | counter | count | Loans written off |

#### Funding (6 counters)

| Metric name | Type | Unit | Description |
|---|---|---|---|
| `funding_deposits_total` | counter | count | Investor deposits |
| `funding_deposits_amount_total` | counter | currency | Total investor deposit amount |
| `funding_withdrawals_total` | counter | count | Investor withdrawals |
| `funding_withdrawals_amount_total` | counter | currency | Total investor withdrawal amount |
| `funding_allocations_total` | counter | count | Loan funding allocations |
| `funding_allocations_amount_total` | counter | currency | Total allocated to loans |

#### Savings (6 counters)

| Metric name | Type | Unit | Description |
|---|---|---|---|
| `savings_accounts_opened_total` | counter | count | New savings accounts |
| `savings_deposits_total` | counter | count | Savings deposits |
| `savings_deposits_amount_total` | counter | currency | Total savings deposited |
| `savings_withdrawals_total` | counter | count | Savings withdrawals |
| `savings_withdrawals_amount_total` | counter | currency | Total savings withdrawn |
| `savings_interest_accrued_amount_total` | counter | currency | Total interest accrued |

#### Operations (6 counters)

| Metric name | Type | Unit | Description |
|---|---|---|---|
| `ops_transfers_executed_total` | counter | count | Transfer orders executed |
| `ops_transfers_amount_total` | counter | currency | Total transfer amount |
| `ops_payments_received_total` | counter | count | Incoming payments received |
| `ops_payments_amount_total` | counter | currency | Total incoming payment amount |
| `ops_payments_allocated_total` | counter | count | Payments successfully allocated |
| `ops_payments_unmatched_total` | counter | count | Payments that couldn't be matched |

#### Identity (4 counters)

| Metric name | Type | Unit | Description |
|---|---|---|---|
| `identity_organizations_created_total` | counter | count | New organizations registered |
| `identity_org_units_created_total` | counter | count | New org units created |
| `identity_workforce_added_total` | counter | count | Workforce members added |
| `identity_workforce_removed_total` | counter | count | Workforce members removed |

## Seed Dashboard (service-fintech/ui/seed)

### Data source change

`RestAnalyticsDataSource` base URL changes from `AppConfig.identityBaseUrl` to `AppConfig.thesaBaseUrl` (new config entry pointing at `api.stawi.org/thesa`).

The analytics client is updated to call the new POST query endpoints instead of the old GET endpoints.

### Dashboard layout

The dashboard is organized around four decision clusters:

#### Row 1: Business health KPI cards

| Card | Query | Display |
|---|---|---|
| Total Customers | `identity_organizations_created_total`, sum, full range | Count + trend vs previous period |
| Active Loans | `loans_created_total - loans_closed_total - loans_defaulted_total - loans_written_off_total` (derived) | Count |
| Portfolio Value | `loans_disbursed_amount_total - loans_repaid_amount_total` (derived) | Currency + trend |
| Default Rate | ratio: `loans_defaulted_total / loans_created_total * 100` | Percentage |

#### Row 2: Today's activity snapshot

| Card | Query | Display |
|---|---|---|
| Loans Disbursed Today | `loans_disbursed_total`, sum, time_range=today | Count |
| Amount Disbursed Today | `loans_disbursed_amount_total`, sum, time_range=today | Currency |
| Amount Repaid Today | `loans_repaid_amount_total`, sum, time_range=today | Currency |
| Defaults Today | `loans_defaulted_total`, sum, time_range=today | Count |

#### Row 3: Trend charts

- **Customer Growth** — `identity_organizations_created_total` as time series line chart
- **Portfolio Growth** — `loans_disbursed_amount_total` and `loans_repaid_amount_total` overlaid as time series

#### Row 4: Org unit proportions

- **Pie chart** — `loans_disbursed_amount_total` grouped by `partition_id` with `partition_ids: ["*"]`
- Labels resolved from partition names available in tenancy context

### Time range

A `TimeRangeSelector` at the top controls the period for KPI trends and charts. The "today" snapshot row always uses today's date range regardless of the selector.

## Thesa Dashboard (service-thesa/ui)

### Migration

The existing dashboard migrates from the old registry-based providers to calling the same generic POST query API.

### Dashboard content

#### Row 1: Platform KPI cards

- **Total API Requests** — `rpc.server.duration` count across all services
- **Error Rate** — ratio of failed to total RPCs
- **Active Tenants** — `tenancy_tenants_created_total`
- **Notifications Sent** — `notification_sent_total`

#### Row 2: Traffic charts

- **API Traffic Over Time** — `rpc.server.duration` count as time series
- **Payment Volume** — `payment_transactions_total` time series

#### Row 3: Traffic distribution

- **Traffic by Service** — `rpc.server.duration` count grouped by `rpc.service`

#### Row 4: Cluster resources (per service)

- **CPU Utilization** — `container_cpu_usage_seconds_total` grouped by pod/deployment
- **Memory Utilization** — `container_memory_working_set_bytes` grouped by pod/deployment
- **Disk Usage** — `kubelet_volume_stats_used_bytes` / `kubelet_volume_stats_capacity_bytes`
- **Database Storage** — `pg_database_size_bytes` per service database (if postgres-exporter metrics available)

## Deployments

### HTTPRoute for Thesa

Add an HTTPRoute in the gateway namespace routing `api.stawi.org/thesa` → `service-thesa.gateway.svc:80` with URL rewrite stripping the `/thesa` prefix.

## Changes by repo

### service-fintech

- `apps/loans/service/business/metrics.go` — 9 counters + registry
- `apps/funding/service/business/metrics.go` — 6 counters + registry
- `apps/savings/service/business/metrics.go` — 6 counters + registry
- `apps/operations/service/business/metrics.go` — 6 counters + registry
- `apps/identity/service/business/metrics.go` — 4 counters + registry
- Business methods in each service updated to call `counter.Add()` at event points
- `ui/seed/lib/core/data/analytics_client.dart` — update to POST query API
- `ui/seed/lib/core/config/app_config.dart` — add `thesaBaseUrl`
- `ui/seed/lib/main.dart` — point analytics data source at Thesa
- `ui/seed/lib/features/dashboard/dashboard_screen.dart` — redesign for lending KPIs

### service-thesa

- `pkg/analytics/handler.go` — replace with generic query handler (4 POST endpoints)
- `pkg/analytics/queries.go` — remove
- `pkg/analytics/registry.go` — remove service registry types (keep MetricQuery as request schema)
- `pkg/analytics/engine.go` — simplify to direct backend calls with tenant scoping
- `ui/lib/features/dashboard/dashboard_page.dart` — migrate to POST query API, add cluster resources
- `ui/lib/features/analytics/analytics_page.dart` — migrate to POST query API
- `ui/lib/core/services/analytics_client.dart` — update to POST query API

### deployments

- `manifests/namespaces/gateway/unified-api/` — add Thesa HTTPRoute at `/thesa`
