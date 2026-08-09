# Azure SRE Agent Closed-Loop Demo

Internal project tracker for a deterministic, end-to-end Azure SRE Agent incident response demonstration.

## Project Structure

```text
.
├── .github/
│   ├── pull_request_template.md
│   └── workflows/
│       └── deliver-demo.yml
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
│       ├── 06-terraform-foundation.md
│       ├── 07-core-azure-aks.md
│       ├── 08-managed-observability.md
│       ├── 09-protected-github-delivery.md
│       ├── 10-checkout-incident.md
│       ├── 11-sre-agent-foundation.md
│       ├── 12-teams-bridge.md
│       ├── 13-github-connector.md
│       ├── 18-architecture-proposal.md
│       └── README.md
├── deploy/
│   └── helm/
│       └── sre-demo/
│           ├── templates/
│           ├── Chart.yaml
│           ├── values.schema.json
│           └── values.yaml
├── iac/
│   ├── modules/
│   │   ├── aks/
│   │   ├── aks-monitoring/
│   │   ├── container-registry/
│   │   ├── identities/
│   │   ├── network/
│   │   ├── observability/
│   │   ├── resource-group/
│   │   ├── sre-agent/
│   │   └── teams-bridge/
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars.example
│   └── variables.tf
├── scripts/
│   ├── audit-tags.sh
│   ├── configure-sre-github-connector.sh
│   ├── configure-sre-teams-connector.sh
│   ├── configure-github-protection.sh
│   ├── deploy-teams-bridge.sh
│   ├── package-teams-app.sh
│   ├── preflight.sh
│   ├── provision-teams-bot-identity.sh
│   ├── publish-images.sh
│   ├── render-teams-icons.py
│   ├── verify-deployment.sh
│   ├── verify-github-connector.sh
│   ├── verify-teams-bridge.sh
│   ├── verify-terraform.sh
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
    ├── frontend/
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
    └── teams-bridge/
        ├── appPackage/
        ├── bridge/
        ├── tests/
        ├── function_app.py
        ├── host.json
        ├── pyproject.toml
        ├── requirements.txt
        └── uv.lock
```

## Stages

- **Stage 1 - Preflight and repository bootstrap:** Complete
- **Stage 2 - Initial backend and frontend:** Complete
- **Stage 3 - Local application review:** Complete
- **Stage 4 - Local observability and release correlation:** Complete
- **Stage 5 - Hardened containers and Helm deployment:** Complete
- **Stage 6 - Modular Terraform foundation:** Complete
- **Stage 7 - Core Azure and AKS platform:** Complete
- **Stage 8 - Managed Azure observability:** Complete
- **Stage 9 - Protected GitHub Actions delivery:** Complete
- **Stage 10 - Deterministic checkout incident and alert:** Complete
- **Stage 11 - Azure SRE Agent and Azure Monitor incident platform:** Complete
- **Stage 12 - Teams connector and threaded notifications:** Complete
- **Stage 13 - GitHub connector capability validation:** Complete
- **Stages 14-17:** Not started; see `docs/stages/README.md`
- **Stage 18 - User-owned Azure architecture proposal with Codex:** Not started
- **Stage 19 - Final learning materials and Terraform teardown:** Not started

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
- Build application images on the local/runner Docker daemon and publish them with `docker push`; do not use `az acr build`, `az acr import`, or remote ACR tasks.

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
- Local and injected test exporters use isolated `TracerProvider` instances. The Azure-enabled production provider is registered globally because the Azure Monitor exporter derives Application Insights resource metadata from the global SDK provider.
- Application Insights ingestion uses AKS workload identity and `Monitoring Metrics Publisher`; local authentication remains disabled.

## Container and Helm Contract

- Backend builds a wheel in `python:3.12.13-slim-bookworm` and copies only its virtual environment into the runtime stage. Runtime UID/GID is `10001`.
- Frontend builds with `node:24.13.1-alpine3.22` and serves static files with `nginxinc/nginx-unprivileged:1.29.4-alpine3.23` as UID/GID `101`.
- Build package resolution continues through the committed Microsoft npm and PyPI proxies.
- Nginx has a baked same-origin proxy to the stable `backend` Service. This intentionally avoids runtime configuration writes and init-container permission changes.
- Helm workload pods meet the Kubernetes Restricted profile: non-root, explicit `RuntimeDefault` seccomp, no privilege escalation, dropped `ALL` capabilities, read-only root filesystem, and allowed `emptyDir` only for `/tmp`.
- Service-account token automount and Kubernetes service-link environment injection are disabled.
- The chart supports immutable `repository@sha256:digest` references; Stage 9 delivery must set them for both images.
- `scripts/publish-images.sh` targets `linux/amd64`, uses immutable Git-SHA tags, performs only local `docker build` plus `docker push`, and emits the pushed digests for Helm. It assumes Docker authentication is already established and never accepts credentials.
- Azure Managed Prometheus discovery uses `azmonitoring.coreos.com/v1` with label limits `63/511/1023` required by Microsoft guidance.
- NetworkPolicies allow public/ingress-controller access to frontend, frontend access to backend, monitoring-namespace access to backend metrics, DNS egress, backend HTTPS egress for Microsoft Entra/Azure Monitor, and optional traffic-generator access to frontend.
- Subscription policy inspection found only SQL/data Defender assignments and no AKS workload or registry restriction.
- Docker Scout critical CVE scanning requires an authenticated Docker account in this environment and was not bypassed. SPDX SBOM generation succeeds locally; authenticated vulnerability scanning is required in Stage 9 CI.
- No local Kubernetes cluster is reachable. API-server admission, Cilium policy enforcement, and `helm test` are deferred to the newly provisioned AKS cluster in Stage 7 and must not be reported as already validated.

## Terraform Contract

- All `.tf` files are under `iac/`; child modules use only relative `./modules/<name>` sources.
- State is local for the learning demo. State, plans, `.terraform/`, `terraform.tfvars`, and auto tfvars are ignored. No `backend.tf` exists.
- Providers are pinned and locked: AzureRM 4.81.x, AzureAD 3.9.x, AzAPI 2.11.x, random 3.9.x. AzureRM 5 is intentionally deferred because current implementation guidance and validation target 4.x.
- Subscription and tenant IDs are required variables and are not hardcoded in HCL. AzureRM automatic provider registration is disabled. Shared provider registrations are verified as pre-existing prerequisites and are not imported into environment state, preventing destroy from unregistering providers used elsewhere.
- Root naming uses a persisted six-character random suffix unless a deterministic suffix is supplied. ACR and Grafana names enforce service length/character restrictions.
- Shared tags are merged at root, with `SecurityControl=Ignore` applied last so callers cannot override it.
- Core modules: resource group, network, ACR, AKS, GitHub Actions identity/OIDC/RBAC.
- Optional modules: observability and AKS monitoring (`enable_observability`) plus SRE Agent (`enable_sre_agent`). Both are enabled in the ignored demo configuration.
- AKS Standard uses Azure CNI Overlay with Cilium, managed identity, OIDC/workload identity, managed Entra authentication, Azure RBAC, disabled local accounts, Azure Policy, Key Vault CSI rotation, Azure Linux ephemeral system disks, host encryption, automatic patch/node-image upgrades, and no node public IPs.
- ACR uses Standard SKU, disables admin and anonymous access, and remains public to support the confirmed local Docker/GitHub runner push model. AKS kubelet receives `AcrPull`; GitHub OIDC identity receives `AcrPush` and AKS deployment roles.
- GitHub federation uses the immutable environment subject `repo:msftse@259423729/sre-agent-demo@1323141369:environment:demo`, not a broad branch subject. Terraform supports legacy subjects for older repositories when immutable IDs are null.
- Observability creates workspace-based Application Insights, Log Analytics, Azure Monitor managed Prometheus, Managed Grafana 12, and reader RBAC. AKS monitoring owns Prometheus/Container Insights DCR associations, selected control-plane diagnostics, and passwordless telemetry identity/RBAC.
- SRE Agent uses `Microsoft.App/agents@2026-01-01` through AzAPI, Review mode, Low access, `AzMonitor`, and demo-resource-group scope. A dedicated UAMI is attached beside the platform system identity and is referenced by both action and knowledge configuration.
- `scripts/verify-terraform.sh` performs no apply. It validates provider prerequisites, agent mode/incident settings, the SRE RBAC allowlist, zero destroys, Checkov, and planned tags across core and full plans.
- Checkov result: 24 passed, 0 failed, 13 explicitly reasoned skips. Skips document confirmed demo constraints (public/single-region/free/Standard/no-CMK) or features intentionally attached in later stages.
- `scripts/audit-tags.sh` is the required post-apply live tag gate. It explicitly reports and excludes only `Microsoft.AlertsManagement/smartDetectorAlertRules`, because Azure auto-creates the Application Insights Failure Anomalies child and neither ARM nor AzureRM exposes writable tags for that type.
- `aks_operator_object_id` is an opt-in Microsoft Entra user object ID for cluster-scoped AKS RBAC administrator access. It defaults to `null`; the ignored demo configuration enables it because subscription `Owner` does not grant Kubernetes data-plane access.
- Azure-managed public IP metadata is ignored through `ip_tags` lifecycle handling so Terraform does not replace the reserved ingress address to remove `FirstPartyUsage=/Unprivileged`.
- Subscription-managed Defender for Containers is preserved through `microsoft_defender` lifecycle handling so AKS monitoring updates cannot disable the external security profile.

## Stage 7 Deployed Platform

- Core resources use deterministic suffix `ij2608` in Sweden Central. Terraform tracks 16 resources and the final live plan has zero drift.
- AKS `aks-sre-agent-demo-demo-ij2608` runs two Ready `Standard_D2ds_v5` Azure Linux 3 nodes with host encryption and Kubernetes `v1.35.6`.
- ACR `acrsreagentdemodemoij2608` contains locally built AMD64 backend and frontend images tagged `4b78b371d14a`; the Helm release uses their immutable registry digests.
- Helm release `northstar` revision 2 runs two ready replicas of each application component in the Restricted `northstar` namespace.
- The Helm test pod carries release selector labels so Cilium admits only the chart's test identity to backend readiness. The live backend and frontend smoke test passes.
- Managed Prometheus discovery is disabled until Stage 8 creates its CRD and Azure Monitor workspace. The reserved public IP `4.223.157.176` is not attached to an ingress controller yet.
- The post-apply tag gate passed for 13 live resources across the primary and AKS-managed resource groups.

## Stage 8 Managed Observability

- Terraform tracks 29 resources with zero drift after enabling Azure Monitor managed Prometheus, Container Insights, selected AKS control-plane diagnostics, workspace-based Application Insights, and Managed Grafana 12.
- Azure Monitor agents are healthy: two metrics and two logs daemon pods, two metrics replicas, one kube-state-metrics replica, and one logs replica.
- Container Insights collects only `ContainerLogV2`, `KubeEvents`, and `KubePodInventory` for namespace `northstar` at a five-minute interval.
- `northstar-sre-demo-backend` scrapes `/metrics` every 30 seconds through the Azure Monitor `ServiceMonitor` CRD.
- Application Insights uses a federated telemetry identity scoped to `Monitoring Metrics Publisher` on the component; no client secret exists.
- Helm release `northstar` revision 5 runs four ready pods at Git SHA `0e23af6890c3` with immutable ACR digests and a passing smoke test.
- Managed Prometheus returned both `northstar_build_info` series, Log Analytics returned correlated operation/trace IDs and 200/422 outcomes, and Application Insights returned Northstar requests, dependencies, and exceptions.
- The live tag gate audited 21 resources and skipped one explicitly reported, non-taggable Application Insights smart detector child.

## Stage 9 Protected Delivery

- `scripts/configure-github-protection.sh` switches between `routine` and `incident-demo`. Routine mode permits direct implementation pushes while retaining linear history and force-push/deletion protection. Incident-demo mode additionally requires the validation check, one approval by someone other than the last pusher, stale-review dismissal, resolved conversations, and admin enforcement.
- PRs are reserved for fixes authored after an actual SRE Agent investigation; routine implementation stages commit directly. Enable `incident-demo` before the remediation exercise.
- Pull requests automatically run backend, frontend, dependency-audit, and Helm validation. Deployment remains `workflow_dispatch` only.
- The `demo` environment accepts only `main` and requires `ij-23` approval. Deployment self-review is allowed because `ij-23` is currently the sole environment reviewer; independent review is enforced at the PR boundary.
- Workflow permissions are `contents: read` plus job-scoped `id-token: write`. Third-party actions and tool versions are pinned.
- Images are built on the runner Docker daemon and published with `docker push`; no ACR build/import/task command is used.
- Trivy blocks fixed critical vulnerabilities and generates SPDX SBOMs before deployment. The first run blocked `CVE-2026-31789`; the patched Alpine OpenSSL packages passed the replacement run.
- Successful run `31112420552` deployed Helm revision 6 at commit `61f739ca6d55bc734ad67e3171da3b83994c3912`; all four replicas and the in-cluster Helm test passed.

## Stage 10 Dormant Checkout Incident

- `checkout()` intentionally returns HTTP 500 with `discount_calculation_failed` only after a valid `FIELD20` quote. Existing tests pass because valid FIELD20 checkout is the deliberate missing case.
- The traffic generator defaults off. When enabled, it submits two `field-pack-28` items with FIELD20 every five seconds and continues after failures.
- The delivery workflow exposes `incident_traffic`; the live incident uses `deploy=true` and `incident_traffic=true` only after SRE Agent and Teams are connected.
- Managed Prometheus alert `NorthstarCheckoutFailureRatioHigh` is severity 1, requires more than 50% checkout 5xx plus active traffic across two minutes, and auto-resolves after five healthy minutes.
- Azure SRE Agent discovers fired alerts through the native Azure Monitor scanner; the temporary empty action group was removed in Stage 11.
- The healthy Stage 9 image remains deployed, traffic is disabled, and no Stage 10 alert is firing.

## Stage 11 SRE Agent Foundation

- Azure SRE Agent `sre-sre-agent-demo-demo-ij2608` is `Succeeded`, `Running`, and reachable at its generated Sweden Central `azuresre.ai` endpoint.
- Native incident management is `AzMonitor`. Subscription-scoped Monitoring Contributor lets the UAMI scan, acknowledge, and synchronize Azure Monitor alerts without an action group.
- Resource access uses UAMI `id-sre-sre-agent-demo-demo-ij2608`. It has Reader, Monitoring Reader, and Log Analytics Reader on the demo resource group plus AKS Cluster User and AKS RBAC Reader on the cluster.
- The agent has no Contributor, Owner, AKS admin, sandbox, or VNet integration. Global Review/Low is the fallback; the Stage 15 checkout response plan will use Autonomous mode for connector actions constrained by tool policy and GitHub permissions.
- Direct ARM creation produced no quickstart response plan. Live data-plane collections show zero threads, incident filters, connectors, custom agents, and plugins.
- The 2026 API requires the UAMI resource ID in both `actionConfiguration.identity` and `knowledgeGraphConfiguration.identity`; omitting it returns `InvalidIdentity`.
- Terraform tracks 39 resources with zero drift. Checkov passes 24 checks with zero failures, all four application pods remain Ready, traffic is disabled, and no checkout alert is active.

## Stage 12 Teams Bridge

- Azure Bot Service F0 forwards Teams activities to Python 3.12 Functions Flex Consumption; five Functions are registered and the host is healthy.
- Inbound requests require Bot Connector JWT validation plus exact tenant, Team `aadGroupId`, channel, and operator boundaries. The safe `status` command proved the live inbound path without starting an investigation.
- The bridge MCP endpoint requires `x-mcp-key`, keeps DNS-rebinding protection, and exposes only post, threaded reply, and route lookup tools for the fixed destination.
- UAMI access is limited to keyless host storage roles, Key Vault Secrets User, and SRE Agent Standard User. The operator can rotate secrets only in the bridge vault.
- `scripts/configure-sre-teams-connector.sh` performs secret-safe, idempotent data-plane creation/update of `northstar-teams` and verifies its exact three prefixed tools. It is called automatically after every successful bridge deployment.
- Live outbound testing created a validation root post and same-thread reply, then read the fixed route back. No SRE investigation or checkout alert was created.
- Terraform tracks 62 resources with zero drift; incident traffic remains disabled.

## Stage 13 GitHub Connector

- `northstar-github` connects Azure SRE Agent to GitHub's official remote MCP server and is constrained to five selected tools: source search/read, branch creation, multi-file commit, and pull-request creation.
- Merge, review, Copilot-authored PR, general PR mutation, branch-update, and deployment capabilities are absent from the selected tool set.
- `scripts/configure-sre-github-connector.sh` performs secret-safe MCP discovery, idempotent data-plane registration, and exact saved-tool verification without printing the GitHub credential.
- `scripts/verify-github-connector.sh` validates the live connector and the independent main-branch and protected-environment controls.
- A live `get_file_contents` call read `README.md` from `main`; no branch, commit, PR, workflow, deployment, investigation, or alert was created.
- The demo uses the active `ij-23` GitHub CLI credential, whose scopes are broader than the selected MCP tools. Production should use a dedicated repository-scoped GitHub App or fine-grained service credential.
