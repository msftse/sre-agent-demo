# Internal Changelog

This append-only log records implementation changes by date.

### 2026-08-08 - Add protected GitHub Actions delivery

- Added PR-triggered backend, frontend, dependency, and Helm validation plus enforced independent approval on `main`.
- Added manual `demo` delivery with main-only environment approval, immutable GitHub OIDC, local Docker builds, ACR push, digest-pinned Helm rollout, and live AKS verification.
- Pinned third-party actions and tool versions, added critical-CVE blocking and SPDX SBOM generation, and kept workflow token permissions least-privilege.
- Proved the scan gate failed closed on frontend OpenSSL `CVE-2026-31789`, patched `libcrypto3`/`libssl3`, and passed the replacement workflow.
- Deployed Helm revision 6 from successful run `31112420552` at commit `61f739ca6d55bc734ad67e3171da3b83994c3912` with all replicas and smoke tests healthy.

### 2026-08-06 - Add managed Azure observability

- Enabled AKS managed Prometheus and MSI-authenticated Container Insights with cost-scoped DCR associations and selected control-plane diagnostics.
- Added Log Analytics, workspace-based Application Insights, Azure Monitor workspace, Managed Grafana 12, and least-privilege Grafana reader access.
- Added passwordless Application Insights trace export through AKS workload identity and `Monitoring Metrics Publisher`, preserving disabled local authentication.
- Enabled the Azure Monitor `ServiceMonitor`, backend HTTPS telemetry egress, and global production tracer-provider registration required by the exporter.
- Verified two Prometheus release series, correlated ContainerLogV2 operation/trace records, and Application Insights request/dependency/exception telemetry.
- Kept the live tag audit strict while explicitly reporting Azure's non-taggable, auto-created Failure Anomalies smart detector child.
- Finished with 29 Terraform resources at zero drift and Helm revision 5 healthy at Git SHA `0e23af6890c3`.

### 2026-08-06 - Provision core Azure and AKS platform

- Applied checksum-reviewed Terraform plans for the core platform and an opt-in, cluster-scoped human AKS administrator assignment; final state tracks 16 resources with zero drift.
- Registered the approved `Microsoft.Compute/EncryptionAtHost` prerequisite, provisioned two Ready encrypted Azure Linux AKS nodes, and preserved Azure-managed public IP metadata without replacing `4.223.157.176`.
- Built both AMD64 application images on the local Docker daemon, published them to ACR with `docker push`, and deployed the immutable registry digests through Helm.
- Corrected the Helm test pod identity and backend Cilium policy selector, then passed the backend/frontend in-cluster smoke test under Restricted Pod Security.
- Audited all 13 live resources across the primary and AKS-managed resource groups for `SecurityControl=Ignore`.

### 2026-08-05 - Add modular Terraform foundation

- Added pinned and locked AzureRM, AzureAD, AzAPI, and random providers with local ignored state and explicit provider registration.
- Added focused Terraform modules for resource group, network, ACR, Cilium AKS, GitHub OIDC identity/RBAC, optional observability, and optional Azure SRE Agent.
- Added mandatory shared tags with `SecurityControl=Ignore`, validated naming/CIDR/SKU inputs, and useful deployment outputs.
- Added no-apply core/full planning, Checkov scanning, plan JSON tag auditing, and a post-apply live Azure tag audit script.
- Validated 27 default resources and 33 full-feature resources; no Terraform apply or Azure resource creation occurred.

### 2026-08-06 - Keep shared provider registrations outside environment state

- Recovered safely from an apply that stopped before Azure resource creation because subscription providers already existed.
- Moved provider registration to read-only preflight verification so environment destroy cannot unregister providers shared with other workloads.
- Updated core/full plan expectations to 15 and 21 resources respectively.

### 2026-08-05 - Add hardened images and AKS Helm chart

- Added pinned multi-stage backend and frontend images that install from the Microsoft package proxies and run as non-root users.
- Added unprivileged Nginx same-origin API/health/metrics proxying, SPA fallback, security headers, and container health checks.
- Added an AKS Helm chart with Restricted pod security, probes, resources, immutable digest support, PDBs, NetworkPolicies, optional ingress and traffic generation, and a Helm test pod.
- Added Azure Managed Prometheus ServiceMonitor discovery with Microsoft-required label limits.
- Added Helm values schema validation and a one-shot verifier for builds, restricted runtime smoke tests, chart modes, security assertions, SBOM generation, and cleanup.
- Added a local Docker build-and-push workflow using immutable AMD64 Git-SHA tags and registry digests; no ACR-side build/import command is used.

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
