# Internal Changelog

This append-only log records implementation changes by date.

### 2026-08-09 - Make deployment documentation environment-portable

- Replaced recreated-environment Azure names, subscription and tenant IDs, endpoints, Team identifiers, public IPs, and generated suffixes with Terraform output or Azure CLI discovery commands.
- Updated the core platform, observability, protected delivery, incident, SRE Agent, and Teams stage records so transient values are either discovered live or explicitly labeled as historical validation evidence.
- Preserved stable application constants, repository identity, local development addresses, and all prior append-only changelog history.
- Executed every documented Terraform output lookup against the current state and completed a repository-wide Markdown scan for stale environment values.

### 2026-08-09 - Add signed GitHub continuation loop

- Added a Key Vault-backed, HMAC-validated GitHub webhook for PR, workflow-run, and deployment-status events.
- Added strict same-repository SRE-branch, main-base, workflow, environment, and thread-marker boundaries for the public repository.
- Added durable PR/merge/SRE/Teams correlation and resumable delivery-ID deduplication in Table Storage.
- Added existing-thread SRE continuation, Teams milestone replies, PR-state verification, and final RCA comment capability without merge or workflow-dispatch tools.
- Hardened Function publishing against Core Tools injecting an empty classic `AzureWebJobsStorage` setting over managed identity.
- Verified 31 tests, signed 202/unsigned 401 delivery, one exact webhook, zero Terraform drift, disabled traffic, zero alerts, and zero open PRs.

### 2026-08-09 - Add autonomous checkout incident responder

- Added a custom checkout responder with no direct tools and access only to the portable checkout remediation skill.
- Added mandatory root and threaded Teams timeline instructions with a fail-closed boundary before source writes.
- Added one active Autonomous Azure Monitor response plan matching only Sev1 `NorthstarCheckoutFailureRatioHigh` alerts with a three-hour recurrence merge window.
- Extended automatic deployment and verification through responder and plan creation in dependency order.
- Proved idempotent bootstrap, no quickstart plan, disabled incident traffic, and zero active checkout alerts.

### 2026-08-09 - Add portable SRE checkout skill

- Added an environment-portable checkout investigation/remediation skill used only by Azure SRE Agent, with runtime discovery for all Azure resource identifiers.
- Removed the abandoned `.github/skills` approach so GitHub Copilot does not discover or execute the skill as repository customization.
- Added native data-plane skill upsert and exact live-content/tool verification derived from Terraform outputs and active Azure context.
- Added a unified deployment bootstrap that configures Teams, GitHub, and the skill in dependency order after every Teams bridge deployment.
- Proved idempotent live installation of one custom skill with nine tools while keeping incident traffic disabled and creating no branch or pull request.

### 2026-08-09 - Validate least-privilege GitHub connector

- Added secret-safe, idempotent Azure SRE Agent registration for GitHub's official remote MCP server.
- Exposed exactly five source-read and branch/commit/PR tools while withholding merge, review, PR mutation, and deployment capabilities.
- Added a repeatable live verifier for connector metadata, branch enforcement, deployment approval, and workflow token restrictions.
- Proved a live read of `README.md` from `main`, connector idempotency, and unchanged human merge/deployment boundaries without creating a branch or pull request.

### 2026-08-09 - Move architecture proposal to the end

- Moved the architecture proposal from Stage 13 to user-owned Stage 18 so it can be run manually with Codex after the full workflow rehearsal.
- Restored GitHub validation, checkout skill, response plan, continuation, and rehearsal to Stages 13-17 while keeping final learning materials and teardown at Stage 19.

### 2026-08-09 - Add Azure architecture proposal stage

- Added Stage 13 for a self-contained, customer-facing HTML architecture design built with the `azure-architecture-proposal` skill.
- Defined the proposal as a greenfield/general Azure design grounded in repository and live Stage 1-12 evidence, with diagrams for topology, closed-loop flow, and approval boundaries.
- Renumbered GitHub validation, checkout skill, response plan, continuation, rehearsal, and teardown through Stage 19.

### 2026-08-09 - Add Teams bridge and automated SRE connector

- Added a Python 3.12 Functions Flex bridge, Azure Bot F0/Teams channel, Durable workflow, keyless storage, Key Vault, UAMI, and a sideloadable Azure SRE Agent Teams package.
- Enforced exact tenant, Team, channel, and operator boundaries on inbound activities and fixed Team matching to use the Graph `aadGroupId` field.
- Exposed only three authenticated MCP tools for fixed-channel root posts, threaded replies, and route lookup; validated 401 without the key and exact discovery with it.
- Added secret-safe, idempotent `northstar-teams` connector creation through the SRE Agent data plane and integrated it into every bridge deployment.
- Verified inbound status, outbound root/reply threading, 13 tests, five live Functions, 62 Terraform resources at zero drift, disabled incident traffic, and zero active checkout alerts.

### 2026-08-09 - Deploy Azure SRE Agent foundation

- Deployed a Stable Azure SRE Agent with native Azure Monitor incident discovery, global Review/Low safeguards, and demo-resource-group knowledge scope.
- Added the required dedicated UAMI and least-privilege monitoring, Log Analytics, and AKS reader roles; granted the operator SRE Agent Administrator only on the agent resource.
- Removed the temporary empty checkout action group because native Azure Monitor scanning discovers fired alerts directly.
- Added Terraform assertions for agent settings, the RBAC allowlist, tags, Checkov, and zero-destroy planning.
- Verified a reachable empty data plane, no quickstart response plan or connectors, 39 Terraform resources at zero drift, a healthy four-pod workload, disabled traffic, and no active checkout alert.
- Added a dedicated Northstar checkout skill stage before response-plan activation and renumbered the remaining roadmap through Stage 18.

### 2026-08-09 - Prepare deterministic checkout incident

- Added a deliberate missing-test regression where valid FIELD20 checkout returns `discount_calculation_failed` with HTTP 500 while health and ordinary checkout remain healthy.
- Added disabled-by-default, failure-tolerant FIELD20 traffic and an explicit GitHub deployment input to activate it later.
- Added a severity-1 Managed Prometheus checkout failure-ratio rule plus an action group reserved for Stage 11 incident routing.
- Validated the alert PromQL against the live healthy baseline and moved persistence into PromQL to maintain complete Checkov parsing.
- Finished with 31 Terraform resources at zero drift, all existing tests passing, live traffic disabled, and zero fired checkout alerts.

### 2026-08-08 - Add protected GitHub Actions delivery

- Added PR-triggered backend, frontend, dependency, and Helm validation plus enforced independent approval on `main`.
- Added repeatable `routine` and `incident-demo` protection profiles so implementation work does not create artificial PRs while the actual SRE remediation flow remains enforceable.
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
