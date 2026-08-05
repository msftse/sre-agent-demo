# Stage 4: Local Observability and Release Correlation

## Goal

Give Azure SRE Agent enough deterministic evidence to move from a health symptom to a request, code path, and deployed Git commit. This stage proves the signal model locally before any Azure exporter, monitoring workspace, container, or cluster exists.

## Signal Model

| Signal | Local implementation | Question answered | Azure destination later |
| --- | --- | --- | --- |
| Metrics | Prometheus text at `/metrics` | Is checkout unhealthy, when did it change, and did it recover? | Azure Monitor managed service for Prometheus |
| Logs | One-line structured JSON on stdout | What route, status, error, pod/instance, and release handled the request? | Log Analytics through Container Insights |
| Traces | OpenTelemetry server and checkout spans | Which code path failed, under which trace, and with which exception? | Application Insights through Azure Monitor OpenTelemetry |
| Release identity | `/api/release`, headers, metrics, logs, spans, UI footer | Which Git SHA and immutable image produced the evidence? | All three signal stores and Kubernetes metadata |

## Prometheus Metrics

| Metric | Type | Labels | Purpose |
| --- | --- | --- | --- |
| `northstar_http_requests_total` | Counter | `method`, route template, `status_code` | Request and error rates |
| `northstar_http_request_duration_seconds` | Histogram | `method`, route template | Latency percentiles and trends |
| `northstar_http_requests_in_progress` | Gauge | None | Concurrent work |
| `northstar_checkout_attempts_total` | Counter | `outcome=confirmed|rejected` | Business checkout success/rejection ratio |
| `northstar_build_info` | Gauge fixed at 1 | version, Git SHA, image digest, environment | Release correlation |

Route labels use FastAPI templates rather than raw URLs. No user, email, order, operation, trace, or product identifier is used as a metric label. This keeps time-series cardinality bounded. The `/metrics` scrape endpoint is intentionally excluded from request metrics.

Example local PromQL-compatible expressions:

```promql
sum(rate(northstar_http_requests_total{route="/api/checkout"}[5m])) by (status_code)
```

```promql
sum(rate(northstar_checkout_attempts_total{outcome="rejected"}[5m]))
/
sum(rate(northstar_checkout_attempts_total[5m]))
```

```promql
histogram_quantile(
  0.95,
  sum(rate(northstar_http_request_duration_seconds_bucket[5m])) by (le, route)
)
```

## Correlation Contract

Every instrumented response exposes:

- `X-Operation-ID`: caller-supplied value when present, otherwise a generated UUID.
- `X-Trace-ID`: 32-character OpenTelemetry trace ID.
- `X-Build-SHA`: configured Git commit.

Allowed browser origins can read these headers through CORS. W3C `traceparent` input is honored, which lets a known trace continue across services in later stages.

Structured logs use these common fields:

```json
{
  "message": "request_completed",
  "operation_id": "stage4-confirmed",
  "trace_id": "1234567890abcdef1234567890abcdef",
  "route": "/api/checkout",
  "status_code": 200,
  "duration_ms": 4.354,
  "git_sha": "ab6b331",
  "image_digest": "local-stage4",
  "environment": "local",
  "instance_id": "developer-host"
}
```

Rejected checkout child spans set error status and record the typed domain exception with its human-readable message. The related warning log adds the stable `discount_invalid` or `product_not_found` code.

## Release Configuration

| Environment variable | Default | Deployment source later |
| --- | --- | --- |
| `SRE_DEMO_SERVICE_VERSION` | `0.1.0` | Image/application version |
| `SRE_DEMO_GIT_SHA` | `development` | GitHub Actions commit SHA |
| `SRE_DEMO_IMAGE_DIGEST` | `local` | ACR image digest |
| `SRE_DEMO_INSTANCE_ID` | Hostname | Kubernetes pod name via downward API |
| `SRE_DEMO_TRACE_CONSOLE_EXPORTER` | `false` | Local verification only; disabled in AKS |
| `VITE_GIT_SHA` | `development` | Vite build argument |

`/api/release` returns the backend values, and the storefront footer displays the first 12 characters of its own `VITE_GIT_SHA`.

## Verification

Run:

```bash
./scripts/verify-observability.sh
```

The script starts an isolated backend on port 8001, sends successful and rejected checkout requests under a fixed trace ID, and asserts:

- Correlation and build response headers.
- Release metadata.
- 200 and 422 route/status counters.
- Confirmed and rejected checkout counters.
- Build-info metric labels.
- JSON request and domain-error logs.
- Server and child checkout spans.
- Human-readable exception evidence.

It stops the server and deletes temporary evidence automatically.

Stage validation:

```text
Backend: Ruff passed, strict mypy passed, 11 tests passed, 96.21% coverage
Frontend: 3 tests passed, ESLint passed, SHA-injected production build passed
Live proof: headers, release JSON, Prometheus, JSON logs, and spans correlated
Cleanup: verification port released
```

## Outcome

Stage 4 passed. The signal names and correlation contract are ready to be carried into containers, Helm, and the three Azure observability destinations in later stages.