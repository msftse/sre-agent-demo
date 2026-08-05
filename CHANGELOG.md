# Internal Changelog

This append-only log records implementation changes by date.

### 2026-08-05 - Add hardened images and AKS Helm chart

- Added pinned multi-stage backend and frontend images that install from the Microsoft package proxies and run as non-root users.
- Added unprivileged Nginx same-origin API/health/metrics proxying, SPA fallback, security headers, and container health checks.
- Added an AKS Helm chart with Restricted pod security, probes, resources, immutable digest support, PDBs, NetworkPolicies, optional ingress and traffic generation, and a Helm test pod.
- Added Azure Managed Prometheus ServiceMonitor discovery with Microsoft-required label limits.
- Added Helm values schema validation and a one-shot verifier for builds, restricted runtime smoke tests, chart modes, security assertions, SBOM generation, and cleanup.

### 2026-08-05 - Add local observability and release correlation

- Added bounded Prometheus request, latency, in-progress, checkout outcome, and build-info metrics at `/metrics`.
- Added OpenTelemetry server and checkout spans with W3C trace-context propagation and recorded domain exceptions.
- Added structured JSON request and domain-error logs with operation, trace, release, route, status, duration, environment, and instance fields.
- Added `/api/release`, browser-visible correlation headers, and frontend build-SHA display.
- Added three telemetry contract tests and a one-shot verifier that correlates headers, release JSON, metrics, logs, and spans.

### 2026-08-05 - Complete local application review

- Ran the FastAPI service and React storefront together for desktop and mobile review.
- Added both loopback Vite origins to the backend CORS defaults and covered the IPv4 preflight with an API regression test.
- Replaced external runtime image requests with four deterministic local product assets.
- Verified catalogue loading, quantity controls, valid and invalid discounts, checkout confirmation, responsive layout, and browser error state; the user approved the experience.

### 2026-08-05 - Start the healthy application

- Grouped application projects under `src/backend` and `src/frontend`.
- Added a typed, server-priced FastAPI catalogue, discount, and checkout contract with seven API tests and 97.92% coverage.
- Built the responsive Northstar Supply React storefront with accessible cart, discount, checkout, and confirmation states plus three behavior tests.
- Configured npm, uv, and pip fallback resolution to use the Microsoft package-feed proxies.
- Completed Ruff, mypy, pytest, Vitest, ESLint, TypeScript, production-build, and shipped-dependency audit checks.

### 2026-08-05 - Begin repository bootstrap

- Added the initial repository hygiene and documentation skeleton.
- Recorded the confirmed architecture constraints and staged delivery approach.
- Validated the target Azure subscription, inherited Owner access, required provider registrations, Sweden Central resource support, and regional quota headroom.
- Confirmed GitHub administrator access, configured the empty repository as `origin`, and added a repeatable read-only preflight script.
- Completed Stage 1 without creating Azure resources.
