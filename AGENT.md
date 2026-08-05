# Azure SRE Agent Closed-Loop Demo

Internal project tracker for a deterministic, end-to-end Azure SRE Agent incident response demonstration.

## Project Structure

```text
.
├── .editorconfig
├── .gitignore
├── AGENT.md
├── CHANGELOG.md
├── README.md
├── docs/
│   └── stages/
│       ├── 01-preflight.md
│       ├── 02-application.md
│       ├── 03-local-review.md
│       ├── 04-observability.md
│       ├── 05-containers-helm.md
│       └── README.md
├── deploy/
│   └── helm/
│       └── sre-demo/
│           ├── templates/
│           ├── Chart.yaml
│           ├── values.schema.json
│           └── values.yaml
├── scripts/
│   ├── preflight.sh
│   ├── verify-containers.sh
│   └── verify-observability.sh
└── src/
    ├── backend/
    │   ├── app/
    │   │   ├── catalog.py
    │   │   ├── config.py
    │   │   ├── main.py
    │   │   ├── models.py
    │   │   ├── observability.py
    │   │   └── service.py
    │   ├── tests/
    │   │   ├── test_api.py
    │   │   └── test_observability.py
    │   ├── .dockerignore
    │   ├── Dockerfile
    │   ├── pip.conf
    │   ├── pyproject.toml
    │   └── uv.lock
    └── frontend/
        ├── public/
        │   └── products/
        │       ├── alpine-shell.jpg
        │       ├── field-pack.jpg
        │       ├── ridge-lamp.jpg
        │       └── trail-flask.jpg
        ├── src/
        │   ├── test/
        │   ├── App.css
        │   ├── App.test.tsx
        │   ├── App.tsx
        │   ├── api.ts
        │   ├── index.css
        │   ├── main.tsx
        │   └── types.ts
        ├── .dockerignore
        ├── .npmrc
        ├── Dockerfile
        ├── nginx.conf
        ├── package-lock.json
        ├── package.json
        └── vite.config.ts
```

## Stages

- **Stage 1 - Preflight and repository bootstrap:** Complete
- **Stage 2 - Initial backend and frontend:** Complete
- **Stage 3 - Local application review:** Complete
- **Stage 4 - Local observability and release correlation:** Complete
- **Stage 5 - Hardened containers and Helm deployment:** Complete
- **Stages 6-17:** Not started; see `docs/stages/README.md`

## Key Decisions

- Azure subscription: `be9948d2-4149-4be2-a040-ef1a6dc1c866`.
- Preferred region: Sweden Central, subject to Stage 1 capability validation.
- Backend: Python 3.12 and FastAPI.
- Frontend: React, TypeScript, and Vite.
- Runtime: AKS with GitHub Actions delivery.
- Infrastructure: Terraform only, with all `.tf` files under `iac/`.
- Terraform state: local and ignored by Git for this learning demo.
- Every taggable Azure resource must include `SecurityControl=Ignore`.
- Teams notifications are mandatory at incident start, during material investigation steps, and at completion with the RCA.
- Human GitHub pull-request approval is the deployment authorization boundary.
- Credentials, OAuth grants, personal access tokens, and Terraform state must never be committed.

## Verified Environment

- Azure CLI subscription: `ME-MngEnvMCAP786446-itzhakjanach-1` (`be9948d2-4149-4be2-a040-ef1a6dc1c866`).
- Azure CLI tenant: `6cdedf3f-fe2c-48bd-894d-1c8e5554c0be`; inherited `Owner` is assigned at its management-group scope.
- VS Code Azure extensions are signed in separately as `itzhakjanach@microsoft.com` in the Microsoft tenant. Do not assume extension and CLI contexts are interchangeable.
- Sweden Central supports the planned SRE Agent, AKS, Managed Grafana, Azure Monitor workspace, Application Insights, Log Analytics, and ACR resource types.
- GitHub user `ij-23` has `ADMIN` permission on the empty `msftse/sre-agent-demo` repository.
- System Python 3.12 is absent; use `uv` to provision the pinned Python 3.12 runtime in Stage 2.

## Conventions

- Implement and validate one stage before opening the next stage.
- Keep changes minimal and preserve an executable validation result for each stage.
- Update `README.md`, `AGENT.md`, and `CHANGELOG.md` whenever project behavior or structure changes.
- Use immutable Git SHA image tags for deployed workloads.
- Keep application code under `src/backend` and `src/frontend`.
- Resolve npm packages through `https://packagefeedproxy.microsoft.io/npm/`.
- Resolve Python packages through `https://packagefeedproxy.microsoft.io/pypi/simple`.

## Application Contract

- `GET /health/live` and `GET /health/ready` expose process health.
- `GET /api/products` returns the server-priced synthetic catalogue.
- `POST /api/discounts/validate` normalizes and validates discount codes.
- `POST /api/checkout` reprices products, validates quantities and email, applies discounts, and returns a synthetic confirmation.
- The initial application is intentionally healthy. The deterministic regression is introduced only in Stage 10.

## Local Review Findings

- Serve the frontend from `http://127.0.0.1:5173` and the backend from `http://127.0.0.1:8000` for the documented review path.
- Default CORS configuration permits both `127.0.0.1` and `localhost` Vite origins and has a regression test for the IPv4 preflight.
- Product images are committed static assets under `src/frontend/public/products`; the live app does not depend on third-party image responses.
- Desktop and 390-pixel mobile browser checks passed with no horizontal overflow, console errors, page errors, or failed requests.

## Known Tooling Notes

- FastAPI's current `TestClient` emits a deprecation warning about its `httpx` compatibility layer; tests pass and runtime behavior is unaffected.
- `npm audit --omit=dev` reports zero shipped vulnerabilities. The feed reports 10 high findings in future-version ESLint tooling while recommending contradictory downgrades; no automatic downgrade is applied while lint and build remain clean.

## Observability Contract

- Metrics use the `northstar_` prefix and base units. HTTP labels are limited to method, route template, and status code; checkout outcome is limited to `confirmed` or `rejected`.
- `/metrics` is excluded from request self-instrumentation to avoid scrape feedback.
- `northstar_http_requests_total`, `northstar_http_request_duration_seconds`, and `northstar_http_requests_in_progress` describe request health.
- `northstar_checkout_attempts_total` is the business numerator/denominator used for checkout failure analysis.
- `northstar_build_info` identifies version, Git SHA, image digest, and environment.
- JSON request logs include operation ID, trace/span IDs, route, status, duration, release identity, environment, and instance.
- Domain errors emit a correlated warning with a stable low-cardinality error code. OpenTelemetry checkout spans record the exception message and error status.
- W3C `traceparent` is accepted and propagated; responses expose operation, trace, and build identifiers to allowed browser origins.
- A dedicated `TracerProvider` belongs to each application instance, making tests isolated and allowing the future Azure Monitor exporter to be configured without global-provider conflicts.

## Container and Helm Contract

- Backend builds a wheel in `python:3.12.13-slim-bookworm` and copies only its virtual environment into the runtime stage. Runtime UID/GID is `10001`.
- Frontend builds with `node:24.13.1-alpine3.22` and serves static files with `nginxinc/nginx-unprivileged:1.29.4-alpine3.23` as UID/GID `101`.
- Build package resolution continues through the committed Microsoft npm and PyPI proxies.
- Nginx has a baked same-origin proxy to the stable `backend` Service. This intentionally avoids runtime configuration writes and init-container permission changes.
- Helm workload pods meet the Kubernetes Restricted profile: non-root, explicit `RuntimeDefault` seccomp, no privilege escalation, dropped `ALL` capabilities, read-only root filesystem, and allowed `emptyDir` only for `/tmp`.
- Service-account token automount and Kubernetes service-link environment injection are disabled.
- The chart supports immutable `repository@sha256:digest` references; Stage 9 delivery must set them for both images.
- Azure Managed Prometheus discovery uses `azmonitoring.coreos.com/v1` with label limits `63/511/1023` required by Microsoft guidance.
- NetworkPolicies allow public/ingress-controller access to frontend, frontend access to backend, monitoring-namespace access to backend metrics, DNS egress, and optional traffic-generator access to frontend.
- Subscription policy inspection found only SQL/data Defender assignments and no AKS workload or registry restriction.
- Docker Scout critical CVE scanning requires an authenticated Docker account in this environment and was not bypassed. SPDX SBOM generation succeeds locally; authenticated vulnerability scanning is required in Stage 9 CI.
- No local Kubernetes cluster is reachable. API-server admission, Cilium policy enforcement, and `helm test` are deferred to the newly provisioned AKS cluster in Stage 7 and must not be reported as already validated.
