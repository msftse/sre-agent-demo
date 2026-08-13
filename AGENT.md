# Azure SRE Agent Closed-Loop Demo

Internal project tracker for a deterministic, end-to-end Azure SRE Agent incident response demonstration.

## Project Structure

```text
.
├── .github/
│   ├── pull_request_template.md
│   └── workflows/
│       ├── deliver-demo.yml
│       └── start-demo.yml
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
│       ├── 14-checkout-skill.md
│       ├── 15-incident-response-plan.md
│       ├── 16-continuation-loop.md
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
│   ├── configure-github-webhook.sh
│   ├── configure-sre-agent-capabilities.sh
│   ├── configure-sre-checkout-responder.sh
│   ├── configure-sre-checkout-response-plan.sh
│   ├── configure-sre-checkout-skill.sh
│   ├── configure-sre-github-connector.sh
│   ├── configure-sre-teams-connector.sh
│   ├── configure-github-protection.sh
│   ├── deploy-teams-bridge.sh
│   ├── package-teams-app.sh
│   ├── preflight.sh
│   ├── provision-teams-bot-identity.sh
│   ├── publish-images.sh
│   ├── render-teams-icons.py
│   ├── verify-checkout-skill.sh
│   ├── verify-checkout-response-plan.sh
│   ├── verify-deployment.sh
│   ├── verify-github-connector.sh
│   ├── verify-github-continuation.sh
│   ├── verify-teams-bridge.sh
│   ├── verify-terraform.sh
│   ├── verify-containers.sh
│   └── verify-observability.sh
├── sre-agent-skills/
│   └── northstar-checkout-remediation.md
├── sre-agent-responders/
│   └── northstar-checkout-responder.md
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
- **Stage 14 - Northstar checkout investigation and remediation skill:** Complete
- **Stage 15 - Incident responder, response plan, and Teams timeline:** Complete
- **Stage 16 - GitHub-to-agent-to-Teams continuation loop:** Complete
- **Stage 17 - Full approval and rejection dress rehearsal:** Complete
- **Stage 18 - User-owned Azure architecture proposal with Codex:** Complete
- **Stage 19 - Final learning materials and Terraform teardown:** Not started

## Key Decisions

- Azure subscription and tenant are deployment inputs; verify them with `az account show` and the ignored Terraform variables before every operation.
- Preferred region: Sweden Central, subject to Stage 1 capability validation.
- Backend: Python 3.12 and FastAPI.
- Frontend: React, TypeScript, and Vite.
- Runtime: AKS with GitHub Actions delivery.
- Infrastructure: Terraform only, with all `.tf` files under `iac/`.
- Terraform state: local and ignored by Git for this learning demo.
- Every taggable Azure resource must include `SecurityControl=Ignore`.
- Teams notifications are mandatory at incident start, during material investigation steps, and at completion with the RCA.
- Human merge of the SRE remediation PR is the source authorization boundary; validated `main` merges deploy automatically through the main-only `demo` environment.
- Credentials, OAuth grants, personal access tokens, and Terraform state must never be committed.

## Verified Environment

- The active Azure CLI subscription and tenant must match `TF_VAR_subscription_id` and `TF_VAR_tenant_id`; `scripts/preflight.sh` and `scripts/verify-terraform.sh` enforce this.
- VS Code Azure extensions and Azure CLI may use separate authentication contexts. Do not assume they are interchangeable.
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
- SRE Agent uses `Microsoft.App/agents@2026-01-01` through AzAPI, Review mode, Low access, `AzMonitor`, and demo-resource-group scope. Its log configuration targets the managed Application Insights component for incident traces and audit telemetry. A dedicated UAMI is attached beside the platform system identity and is referenced by both action and knowledge configuration.
- `scripts/verify-terraform.sh` performs no apply. It validates provider prerequisites, agent mode/incident settings, the SRE RBAC allowlist, zero destroys, Checkov, and planned tags across core and full plans.
- Checkov result: 24 passed, 0 failed, 13 explicitly reasoned skips. Skips document confirmed demo constraints (public/single-region/free/Standard/no-CMK) or features intentionally attached in later stages.
- `scripts/audit-tags.sh` is the required post-apply live tag gate. It explicitly reports and excludes only `Microsoft.AlertsManagement/smartDetectorAlertRules`, because Azure auto-creates the Application Insights Failure Anomalies child and neither ARM nor AzureRM exposes writable tags for that type.
- `aks_operator_object_id` is an opt-in Microsoft Entra user object ID for cluster-scoped AKS RBAC administrator access. It defaults to `null`; the ignored demo configuration enables it because subscription `Owner` does not grant Kubernetes data-plane access.
- Azure-managed public IP metadata is ignored through `ip_tags` lifecycle handling so Terraform does not replace the reserved ingress address to remove `FirstPartyUsage=/Unprivileged`.
- Subscription-managed Defender for Containers is preserved through `microsoft_defender` lifecycle handling so AKS monitoring updates cannot disable the external security profile.

## Stage 7 Deployed Platform

- Stage 7 created the core resources under the generated suffix exposed by Terraform and finished with zero drift.
- The AKS output identifies a two-node `Standard_D2ds_v5` Azure Linux system pool with host encryption; query the current Kubernetes version from the live cluster.
- The ACR output identifies the registry containing locally built AMD64 backend and frontend images; Helm uses immutable registry digests.
- Helm release `northstar` runs two ready replicas of each application component in the Restricted `northstar` namespace; revisions are transient.
- The Helm test pod carries release selector labels so Cilium admits only the chart's test identity to backend readiness. The live backend and frontend smoke test passes.
- Managed Prometheus discovery is disabled until Stage 8 creates its CRD and Azure Monitor workspace. The reserved public IP is exposed by Terraform and is not attached to an ingress controller yet.
- The post-apply tag gate passed across the primary and AKS-managed resource groups; resource counts are stage snapshots, not reusable expectations.

## Stage 8 Managed Observability

- Stage 8 finished with zero drift after enabling Azure Monitor managed Prometheus, Container Insights, selected AKS control-plane diagnostics, workspace-based Application Insights, and Managed Grafana.
- Azure Monitor agents are healthy: two metrics and two logs daemon pods, two metrics replicas, one kube-state-metrics replica, and one logs replica.
- Container Insights collects only `ContainerLogV2`, `KubeEvents`, and `KubePodInventory` for namespace `northstar` at a five-minute interval.
- `northstar-sre-demo-backend` scrapes `/metrics` every 30 seconds through the Azure Monitor `ServiceMonitor` CRD.
- Application Insights uses a federated telemetry identity scoped to `Monitoring Metrics Publisher` on the component; no client secret exists.
- Helm release `northstar` runs four ready pods with immutable ACR digests and a passing smoke test; query the current revision and SHA from Helm and `/api/release`.
- Managed Prometheus returned both `northstar_build_info` series, Log Analytics returned correlated operation/trace IDs and 200/422 outcomes, and Application Insights returned Northstar requests, dependencies, and exceptions.
- The Stage 8 tag-gate snapshot audited the deployed resources and skipped one explicitly reported, non-taggable Application Insights smart detector child; counts vary after recreation.

## Stage 9 Protected Delivery

- `scripts/configure-github-protection.sh` switches between `routine` and `incident-demo`. Routine mode permits direct implementation pushes while retaining linear history and force-push/deletion protection. Incident-demo mode additionally requires the validation check, resolved conversations, and admin enforcement; no separate approving review is required because the SRE connector authors PRs as `ij-23`.
- PRs are reserved for fixes authored after an actual SRE Agent investigation; routine implementation stages commit directly. Enable `incident-demo` before the remediation exercise.
- `Start Demo` (`.github/workflows/start-demo.yml`) is the browser entry point. It discovers the latest merged `sre/field20-checkout-*` PR and inverts that merge into a `demo/incident-*` setup PR after proving no setup/remediation PR or delivery is active. `GITHUB_TOKEN` pushes the branch; repository secret `STAGE17_GITHUB_TOKEN` creates and merges only the validated setup PR under organization policy.
- The starter waits for required validation and automatically merges only its generated setup PR; the manual dispatch is the source authorization for incident setup. Human merge of a same-repository `sre/field20-checkout-*` PR starts automatic recovery with traffic disabled. Both paths deploy the merge SHA through the main-only `demo` environment without a reviewer gate.
- The starter credential should be fine-grained or GitHub App based and limited to setup branch and PR operations in this repository. It has no review call and does not match or merge SRE remediation branches.
- The `demo` environment accepts only `main` and has no reviewer gate. The SRE remediation PR merge remains the user action; the agent cannot merge it or dispatch deployment.
- Workflow permissions are `contents: read` plus job-scoped `id-token: write`. Third-party actions and tool versions are pinned.
- Images are built on the runner Docker daemon and published with `docker push`; no ACR build/import/task command is used.
- Trivy blocks fixed critical vulnerabilities and generates SPDX SBOMs before deployment. The first run blocked `CVE-2026-31789`; the patched Alpine OpenSSL packages passed the replacement run.
- The successful Stage 9 replacement run deployed a digest-pinned release; all four replicas and the in-cluster Helm test passed. Workflow run IDs and release SHAs are historical evidence in the stage record, not current environment inputs.

## Stage 10 Dormant Checkout Incident

- `checkout()` intentionally returns HTTP 500 with `discount_calculation_failed` only after a valid `FIELD20` quote. Existing tests pass because valid FIELD20 checkout is the deliberate missing case.
- The traffic generator defaults off. When enabled, it submits two `field-pack-28` items with FIELD20 every five seconds and continues after failures.
- The delivery workflow exposes `incident_traffic`; the live incident uses `deploy=true` and `incident_traffic=true` only after SRE Agent and Teams are connected.
- Recovery-mode Helm tests submit one FIELD20 checkout, assert exact totals, and emit a stable operation ID. The backend span records only `FIELD20` versus `other`, never email or request bodies, so the agent can independently verify recovery in Application Insights.
- Managed Prometheus alert `NorthstarCheckoutFailureRatioHigh` is severity 1, requires more than 50% checkout 5xx plus active traffic across two minutes, and auto-resolves after five healthy minutes.
- Azure SRE Agent discovers fired alerts through the native Azure Monitor scanner; the temporary empty action group was removed in Stage 11.
- The healthy Stage 9 image remains deployed, traffic is disabled, and no Stage 10 alert is firing.

## Stage 11 SRE Agent Foundation

- The SRE Agent returned by the nested Terraform output is `Succeeded`, `Running`, and reachable at its generated data-plane endpoint.
- Native incident management is `AzMonitor`. Subscription-scoped Monitoring Contributor lets the UAMI scan, acknowledge, and synchronize Azure Monitor alerts without an action group.
- Resource access uses the UAMI ID returned by the nested SRE Agent output. It has Reader, Monitoring Reader, and Log Analytics Reader on the demo resource group plus AKS Cluster User and AKS RBAC Reader on the cluster.
- The agent has no Contributor, Owner, AKS admin, sandbox, or VNet integration. Global Review/Low is the fallback; the Stage 15 checkout response plan will use Autonomous mode for connector actions constrained by tool policy and GitHub permissions.
- Direct ARM creation produced no quickstart response plan. Live data-plane collections show zero threads, incident filters, connectors, custom agents, and plugins.
- The 2026 API requires the UAMI resource ID in both `actionConfiguration.identity` and `knowledgeGraphConfiguration.identity`; omitting it returns `InvalidIdentity`.
- The Stage 11 validation finished with zero Terraform drift. Checkov passes 24 checks with zero failures, all four application pods remain Ready, traffic is disabled, and no checkout alert is active; tracked counts vary by enabled features.

## Stage 12 Teams Bridge

- Azure Bot Service F0 forwards Teams activities to Python 3.12 Functions Flex Consumption; five Functions are registered and the host is healthy.
- Inbound requests require Bot Connector JWT validation plus exact tenant, Team `aadGroupId`, channel, and operator boundaries. The safe `status` command proved the live inbound path without starting an investigation.
- The bridge MCP endpoint requires `x-mcp-key`, keeps DNS-rebinding protection, and exposes only post, threaded reply, and route lookup tools for the fixed destination.
- UAMI access is limited to keyless host storage roles, Key Vault Secrets User, and SRE Agent Standard User. The operator can rotate secrets only in the bridge vault.
- `scripts/configure-sre-teams-connector.sh` performs secret-safe, idempotent data-plane creation/update of `northstar-teams` and verifies its exact three prefixed tools. It is called automatically after every successful bridge deployment.
- Live outbound testing created a validation root post and same-thread reply, then read the fixed route back. No SRE investigation or checkout alert was created.
- The Stage 12 validation finished with zero Terraform drift and incident traffic disabled; tracked counts vary by enabled features.

## Stage 13 GitHub Connector

- `northstar-github` connects Azure SRE Agent to GitHub's official remote MCP server and is constrained to seven selected tools: source/PR read, branch creation, multi-file commit, pull-request creation, and final RCA comment.
- Merge, review, Copilot-authored PR, general PR mutation, branch-update, and deployment capabilities are absent from the selected tool set.
- `scripts/configure-sre-github-connector.sh` performs secret-safe MCP discovery, idempotent data-plane registration, and exact saved-tool verification without printing the GitHub credential.
- `scripts/verify-github-connector.sh` validates the live connector and the independent main-branch and protected-environment controls.
- A live `get_file_contents` call read `README.md` from `main`; no branch, commit, PR, workflow, deployment, investigation, or alert was created.
- The demo uses the active `ij-23` GitHub CLI credential, whose scopes are broader than the selected MCP tools. Production should use a dedicated repository-scoped GitHub App or fine-grained service credential.

## Stage 14 Checkout Skill

- `sre-agent-skills/northstar-checkout-remediation.md` is deployment source for an Azure SRE Agent custom skill, not a repository-discoverable Copilot skill; `.github/skills` is absent.
- The skill has eleven temporary tools: read-only Azure investigation, seven constrained GitHub operations, and three fixed-destination Teams operations.
- Runtime instructions discover Azure resource names and IDs from the active incident and live relationships; no environment-specific subscription, resource group, cluster, workspace, namespace, or agent identifier is embedded.
- `scripts/configure-sre-checkout-skill.sh` derives the current agent ID and endpoint from Terraform, validates Azure CLI subscription context, and performs an idempotent native data-plane upsert.
- `scripts/configure-sre-agent-capabilities.sh` configures Teams, GitHub, then the skill and verifies its live content. `scripts/deploy-teams-bridge.sh` invokes this bootstrap after Function health succeeds.
- The live SRE Agent has one custom skill with eleven tools and byte-identical content. Repeated bootstrap runs succeeded without starting an incident or creating GitHub changes.

## Stage 15 Incident Responder

- `northstar-checkout-responder` has no direct tools and exactly one allowed skill, `northstar-checkout-remediation`.
- Its instructions require a Teams root post before source writes and threaded impact, root-cause, PR, blocked/failure, and final-RCA updates.
- Teams root-post failure after one retry blocks branch, commit, and PR creation while allowing read-only evidence collection.
- Active plan `northstar-checkout-response` matches only `Sev1` alerts containing `NorthstarCheckoutFailureRatioHigh`, runs in Autonomous mode, and merges recurring alerts for three hours.
- No quickstart plan or separate incident-handler resource exists; the focused filter routes directly to the custom responder.
- The unified capability bootstrap now configures Teams, GitHub, skill, responder, and plan in dependency order and verifies each live boundary.
- Full bootstrap passed twice with incident traffic disabled and zero active checkout alerts.

## Stage 16 Continuation Loop

- A public `/api/github/events` route validates GitHub HMAC signatures from the Key Vault-backed `github-webhook-secret`; unsigned requests return 401.
- One repository hook exposes exactly `pull_request`, `workflow_run`, and `deployment_status`; a live GitHub-signed ping returns 202.
- Public-repository PR events require the same repository on both sides, base `main`, an `sre/field20-checkout-*` head branch, and exactly one SRE thread marker.
- Workflow/deployment events require the exact delivery workflow, manual dispatch on `main`, `demo` environment, and a previously correlated merge SHA.
- Table Storage persists PR and merge-SHA correlation plus delivery IDs with independent Teams/SRE completion flags for retry-safe deduplication.
- The Function UAMI appends verified events to the original SRE thread and replies in the original Teams thread; successful delivery instructs the agent to verify release/health/FIELD20/telemetry/alert recovery and publish the final PR/Teams RCA.
- GitHub continuation added only `pull_request_read` and `add_issue_comment`; merge, review, mutation, dispatch, and deployment tools remain absent.
- Function publishing is hardened to remove Core Tools' empty classic `AzureWebJobsStorage` override and restart before health checks, preserving managed-identity storage.
- Thirty-one tests, live hook/security checks, and a 60-resource no-drift plan passed; incident traffic remains disabled with zero alerts and open PRs.
