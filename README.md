# service-thesa

Thesa is the **Backend-For-Frontend (BFF)** for the Stawi platform. It is the
single HTTP entry point the Flutter UI talks to: it composes downstream
microservices (profile, payments, files, chat, commerce, ledger, …) behind a
metadata-driven aggregation layer, enforces authorization, and exposes a
uniform `/ui/*` surface so the client never calls backends directly.

Thesa is stateless and owns no database. All domain state lives in the
backend services; Thesa's only persistence is short-lived in-memory caches
(capability resolution, lookups).

---

## What it does

```
Flutter UI ──HTTP──▶ Thesa BFF ──OpenAPI/HTTP──▶ profile / payments / files / …
                        │
                        ├── Keto (authorization, BatchCheck)
                        ├── OIDC (JWT validation via Frame)
                        └── OpenObserve (OTel metrics, read-only analytics)
```

- **Metadata-driven UI.** Each `definitions/*.yaml` declares one domain (users,
  payments, chat, …) with its navigation entries, pages, forms, schemas,
  resources, commands and search/lookup wiring. The UI fetches this metadata
  at runtime and renders accordingly — no per-feature frontend code.
- **Unified operation invoker.** Every action ultimately resolves to either an
  OpenAPI operation on a named backend (from `specs/<svc>.yaml`) or a
  registered SDK handler. The UI never knows the underlying service URL.
- **Capability resolution.** On every request the user's permissions are
  batch-checked against Ory Keto using OPL namespaces; resolved capabilities
  are attached to the request context and used by page/action providers to
  filter what the UI sees.
- **Analytics proxy.** Read-only aggregation over OTel metrics in OpenObserve
  (Prometheus-compatible API) for dashboards. Disabling or breaking this does
  not affect the rest of the BFF — see [Resilience](#resilience) below.

---

## Layout

```
apps/default/cmd/bff/main.go        Entry point — wires Frame, loads defs/specs,
                                    builds providers, starts HTTP server.
apps/default/config/config.yaml     Runtime config (services, CORS, analytics…).
pkg/config/                         Config types + loader; embeds Frame's
                                    ConfigurationDefault so env vars (OAUTH2_*,
                                    LOG_*, SERVICE_NAME, HTTP_PORT…) populate
                                    Frame infrastructure automatically.
pkg/openapi/                        OpenAPI spec index (fast operation lookup).
pkg/definition/                     YAML loader + validator + registry
                                    (atomic pointer swap for hot reload).
pkg/invoker/                        Operation invokers: OpenAPI (HTTP via
                                    Frame HTTPClient) and SDK (in-process).
pkg/capability/                     Capability resolver over Keto (BatchCheck)
                                    with per-request caching.
pkg/metadata/                       Menu / Page / Form / Schema / Resource
                                    providers — turn definitions + invoker
                                    results into UI responses.
pkg/command/                        Command executor for POST /ui/commands/*.
pkg/search/                         Federated search + lookup cache.
pkg/analytics/                      OTel metrics query engine
                                    (Prometheus + OpenObserve backends).
pkg/transport/                      HTTP router + middleware chain
                                    (auth → capabilities → timeout → logging).
definitions/                        12 per-domain YAML definitions.
specs/                              Downstream service OpenAPI specs.
ui/                                 Flutter web client (separate build).
```

---

## Runtime model

Thesa is built on [Frame](https://github.com/pitabwire/frame). Startup flow:

1. Load YAML config (`--config /config/config.yaml`). The `Config` struct
   embeds `frameconfig.ConfigurationDefault`, so standard Frame env vars
   (`SERVICE_NAME`, `HTTP_PORT`, `OAUTH2_*`, `LOG_*`) are read from the
   environment alongside the YAML fields Thesa owns (`services`, `specs`,
   `definitions`, `analytics`, `capability`, …).
2. Load OpenAPI specs from `specs/*.yaml` into the operation index.
3. Load `definitions/*.yaml`, validate them against the loaded OpenAPI specs
   (every `operation_id` must resolve), and publish an atomic registry.
4. Construct the Frame service via `frame.NewServiceWithContext(ctx,
   frame.WithConfig(cfg))`. `WithConfig` picks up `Name()` from the config,
   so the service is registered as `service-thesa`; telemetry, HTTP client,
   security manager (Keto authorizer + OIDC authenticator) come along.
5. Build providers (capability, menu, page, form, schema, resource, command,
   search, lookup, analytics) and wire them into the HTTP router.
6. `svc.Init(ctx, frame.WithHTTPHandler(router))` + health checks.
7. `svc.Run(ctx, ":8080")` blocks until SIGTERM; `defer svc.Stop(ctx)`
   guarantees graceful shutdown (HTTP drain, queue flush, JWKS refresh stop,
   cleanup callbacks).

### Routes

All `/ui/*` routes go through the standard chain:
`authenticate → request-context → capability resolution → timeout → logging`.

| Method & Path                                | Purpose                                    |
| -------------------------------------------- | ------------------------------------------ |
| `GET  /healthz`                              | Frame health (definitions + specs loaded). |
| `GET  /ui/capabilities`                      | Full capability set for the caller.        |
| `POST /ui/capabilities/batch-check`          | Bulk capability check.                     |
| `GET  /ui/navigation`                        | Menu tree filtered by capabilities.        |
| `GET  /ui/pages/{pageId}` + `/data`          | Page metadata / page data source.          |
| `GET  /ui/forms/{formId}` + `/data`          | Form schema / prefilled data.              |
| `GET  /ui/schemas/{schemaId}`                | JSON schema lookup.                        |
| `POST /ui/commands/{commandId}`              | Execute a declared command.                |
| `POST /ui/actions/{actionId}`                | Execute a declared action.                 |
| `GET  /ui/resources/{type}[/search|/{id}]`   | Generic resource read/search.              |
| `GET  /ui/search`                            | Federated cross-domain search.             |
| `GET  /ui/lookups/{lookupId}`                | Cached lookup (TTL from config).           |
| `POST /ui/upload`, `GET /ui/download/{id}`   | Proxied file upload/download.              |
| `GET  /analytics/*`                          | Read-only metric queries (OpenObserve).    |

### Key interfaces with the platform

| System         | Role                                                              |
| -------------- | ----------------------------------------------------------------- |
| **Ory Keto**   | Authorization. `authorizer.NewFunctionChecker` + BatchCheck.      |
| **OIDC / OAuth2** | Authentication. Frame's authenticator validates JWTs; JWKS is refreshed in the background. |
| **Backend services** | Data. Reached via Frame's `HTTPClientManager` client per `services:` entry in config; circuit breaker + retry applied. |
| **OpenObserve** | Metrics. Queried via its Prometheus-compatible API at `/api/{org}/prometheus/api/v1/*`. |

---

## Configuration

Thesa reads a YAML file (`--config`, default `config.yaml`) and environment
variables. The YAML owns *application* concerns (definitions, specs, service
endpoints, analytics backend). Environment variables own *infrastructure*
concerns (OIDC, port, log level).

### Env vars you'll actually set

| Variable                         | Purpose                                              |
| -------------------------------- | ---------------------------------------------------- |
| `SERVICE_NAME`                   | Override service identity (default `service-thesa`). |
| `HTTP_PORT`                      | HTTP listen port (default `8080`).                   |
| `OAUTH2_SERVICE_URI`             | OIDC issuer base URL.                                |
| `OAUTH2_JWT_VERIFY_AUDIENCE`     | Expected audience (`service_thesa`).                 |
| `OAUTH2_JWT_VERIFY_ISSUER`       | Expected issuer.                                     |
| `LOG_LEVEL`                      | `debug` / `info` / `warn` / `error`.                 |
| `ANALYTICS_BACKEND_TYPE`         | `openobserve` or `prometheus`.                       |
| `ANALYTICS_BACKEND_URL`          | Metrics backend URL.                                 |
| `ANALYTICS_ORG`                  | OpenObserve organization (default `default`).        |
| `ANALYTICS_USERNAME` / `_PASSWORD` | OpenObserve basic-auth.                             |
| `AUTHORIZATION_SERVICE_READ_URI` | Keto read endpoint (cluster-internal).               |
| `THESA_SERVER_PORT`              | Legacy override for `server.port` in YAML.           |

### YAML fields you'll actually change

- `services.<id>.base_url` — endpoint for each backend service.
- `services.<id>.authorization_namespace` — Keto namespace for capability checks.
- `services.<id>.circuit_breaker` / `retry` — resilience per service.
- `specs.sources` — which OpenAPI spec files to load and under which
  service ID. Every `operation_id` referenced in `definitions/` must be
  present in some loaded spec or validation will fail at boot.
- `definitions.directories` — where `definitions/*.yaml` live.
- `capability.cache.ttl`, `lookup.cache.ttl` — cache timings.

---

## Resilience

Thesa must never take the platform offline when an ancillary dependency
misbehaves. Two specific rules follow from this:

1. **Analytics is not on the readiness path.** OpenObserve unreachable or
   mis-authenticated is logged at startup and surfaces as 503 on
   `/analytics/*` queries, but `/healthz` stays green. This was not the
   case previously — prior to the fix in this commit, bad OpenObserve
   creds put every pod into a startup-probe restart loop and helm
   remediation uninstalled the release entirely.
2. **OpenObserve has its own `Healthy()`.** OpenObserve does not implement
   the Prometheus `/api/v1/status/buildinfo` endpoint (returns 401
   regardless of credentials), so `OpenObserveBackend.Healthy` hits
   `/api/v1/labels` instead. Use this probe — do not use the generic
   Prometheus one against an OpenObserve target.

What *does* fail startup on purpose:
- Missing or invalid YAML config, invalid definitions, missing operation
  IDs, no OpenAPI specs loaded, no definitions registered. These are
  programmer/deploy errors — crash loud.

---

## Build, test, run

```bash
make build            # Go binary (apps/default/cmd/bff → ./bin/thesa-bff)
make test             # All Go tests
make ui-build-prod    # Flutter web with prod OAuth2 values

# Local run (requires OIDC/Keto reachable — typically via port-forward).
./bin/thesa-bff --config apps/default/config/config.yaml
```

Docker image: `ghcr.io/antinvestor/service-thesa:<tag>` (built by
`.github/workflows/release.yaml` on pushed version tags).

---

## Deployment

Deployed by FluxCD using the `colony` Helm chart; manifest lives in
`antinvestor/deployments` at
`manifests/namespaces/gateway/thesa/service-thesa.yaml`.

- **Namespace:** `gateway`
- **Public hostnames:** `thesa.stawi.org`, `thesa-dev.stawi.org` via
  Envoy Gateway HTTPRoute on `/api`.
- **Replicas:** HPA 1-6, target 80% CPU/memory.
- **Probes:** startup/readiness/liveness all hit `/healthz`.
- **Secrets:** ESO pulls OpenObserve credentials from Vault at
  `antinvestor/gateway/thesa/analytics` into the
  `analytics-credentials-thesa` secret. Stakater Reloader triggers a pod
  rollout when the secret changes.
- **Image automation:** `flux image-automation` picks the highest
  `>=v0.1.0` semver tag from GHCR and rewrites the HelmRelease.

### Release flow

```
commit on main ──▶ draft-release.yaml creates/updates draft GitHub Release
                   (every 5 days) publish-release.yaml publishes the draft,
                   creating a vX.Y.Z git tag
tag push ──▶ release.yaml (docker-release) builds and pushes the image
image pushed ──▶ flux image-reflector sees it, image-automation commits a
                 HelmRelease bump, helm-controller rolls the deployment
```

For urgent fixes, cut and push the tag directly instead of waiting on the
cron.

---

## Observability

- **Traces & metrics:** OpenTelemetry via Frame. Exporter configured from
  standard OTel env vars; service name is `service-thesa`.
- **Logs:** Structured JSON on stdout (`util.Log(ctx)`), level controlled
  by `LOG_LEVEL`.
- **Analytics dashboards:** Read their data from OpenObserve via the same
  Prometheus-compatible API Thesa itself queries.
