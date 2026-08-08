# Azure SRE Agent Closed-Loop Demo

This repository will demonstrate a complete, human-governed incident response flow for a storefront running on Azure Kubernetes Service (AKS):

```text
Azure Monitor alert
  -> Azure SRE Agent investigation and Teams timeline
  -> GitHub fix pull request
  -> human review
  -> GitHub Actions deployment
  -> Azure SRE Agent verification
  -> Teams and GitHub root-cause analysis
```

The application will contain a React storefront and a Python FastAPI checkout service. Azure Monitor managed service for Prometheus, Log Analytics, Application Insights, and Azure Managed Grafana will provide complementary metrics, runtime evidence, traces, and visualization.

## Current Status

Stage 9 is complete. Pull requests require independent approval and automated application/chart validation before merge to `main`. A separately approved GitHub Actions deployment uses immutable OIDC, local Docker builds, critical-CVE blocking, SPDX SBOMs, digest-pinned Helm rollout, and live AKS verification. Stage 10 introduces the deterministic checkout regression and alert through this protected path.

## Quick Start

Run the repeatable prerequisite check from the repository root:

```bash
./scripts/preflight.sh
```

Install and validate the backend:

```bash
cd src/backend
uv sync --locked --all-groups
uv run ruff check .
uv run mypy app tests
uv run pytest
```

Install and validate the frontend:

```bash
cd src/frontend
npm ci
npm test
npm run lint
npm run build
```

Run the application locally in two terminals:

```bash
# Terminal 1
cd src/backend
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

```bash
# Terminal 2
cd src/frontend
npm run dev -- --host 127.0.0.1 --port 5173 --strictPort
```

Open the storefront at `http://127.0.0.1:5173/` and the API documentation at `http://127.0.0.1:8000/docs`.

Run the complete local telemetry proof:

```bash
./scripts/verify-observability.sh
```

Build and validate both images and every Helm chart mode:

```bash
./scripts/verify-containers.sh
```

After a registry exists and Docker is authenticated, build and push both AKS images from the local Docker daemon:

```bash
./scripts/publish-images.sh --registry <acr-name>.azurecr.io
```

This project does not use ACR build/import commands. The script targets `linux/amd64`, publishes immutable Git-SHA tags with `docker push`, and prints the pushed digests for Helm.

Validate the Terraform foundation without applying resources:

```bash
export TF_VAR_subscription_id="<subscription-id>"
export TF_VAR_tenant_id="<tenant-id>"
./scripts/verify-terraform.sh
```

After a future apply, audit the mandatory resource tags:

```bash
./scripts/audit-tags.sh \
  --resource-group "$(terraform -chdir=iac output -raw resource_group_name)" \
  --resource-group "$(terraform -chdir=iac output -raw aks_node_resource_group)"
```

The backend uses Python 3.12 provisioned by `uv`. npm and Python dependencies resolve through the Microsoft package-feed proxies committed in each project. If a direct pip fallback is ever required, run it with `PIP_CONFIG_FILE=pip.conf` from `src/backend`.

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
│   │   └── sre-agent/
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars.example
│   └── variables.tf
├── scripts/
│   ├── audit-tags.sh
│   ├── preflight.sh
│   ├── publish-images.sh
│   ├── verify-deployment.sh
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

## Delivery Approach

The demo is built one stage at a time. Each stage starts with an explanation of its purpose and expected changes, and ends with validation, documentation, review, and a scoped commit.

See [docs/stages/README.md](docs/stages/README.md) for the stage map and progress.

Application code is grouped under `src/`: the Python API lives in `src/backend`, and the React application lives in `src/frontend`.

## Healthy Application

The FastAPI service exposes health probes, a server-priced product catalogue, discount validation, and checkout. The storefront consumes that contract to provide catalogue loading, quantity controls, discount feedback, computed totals, checkout, confirmation, and explicit loading/error states. All data is synthetic and no payment or personal data is persisted.

## Local Observability

The backend exposes Prometheus metrics at `/metrics` and release metadata at `/api/release`. Every application response includes `X-Operation-ID`, `X-Trace-ID`, and `X-Build-SHA`. JSON request/error logs and OpenTelemetry request/checkout spans carry those same identifiers so an investigation can move between a metric, a log, a trace, and the responsible Git commit.

Set release identity through these environment variables:

| Variable | Local default | Purpose |
| --- | --- | --- |
| `SRE_DEMO_SERVICE_VERSION` | `0.1.0` | Application version |
| `SRE_DEMO_GIT_SHA` | `development` | Source commit deployed |
| `SRE_DEMO_IMAGE_DIGEST` | `local` | Immutable container identity when available |
| `SRE_DEMO_INSTANCE_ID` | Hostname | Process/pod identity |
| `SRE_DEMO_TRACE_CONSOLE_EXPORTER` | `false` | Print spans locally for learning and verification |
| `VITE_GIT_SHA` | `development` | Frontend build marker |

See [docs/stages/04-observability.md](docs/stages/04-observability.md) for signal definitions and sample queries.

## Containers and Helm

The backend runtime uses Python 3.12 as UID/GID `10001`; the frontend runtime uses unprivileged Nginx as UID/GID `101`. Both support read-only root filesystems, drop all Linux capabilities, expose health checks, and carry OCI version/revision/source labels. Production frontend requests use same-origin paths and Nginx proxies API, health, and metrics traffic to the stable `backend` Kubernetes Service.

The Helm chart defaults to two replicas per service, Restricted Pod Security, no service-account token mounts, explicit requests/limits/probes, component NetworkPolicies, PDBs, and an Azure Managed Prometheus `ServiceMonitor`. Production deployments should set ACR image digests rather than relying on tags.

See [docs/stages/05-containers-helm.md](docs/stages/05-containers-helm.md) for chart values and validation details.

## Terraform Foundation

All Terraform files live under `iac/`. State is local and ignored; there is intentionally no `backend.tf`. AzureRM automatic provider registration is disabled, and required subscription-wide providers are validated as pre-existing prerequisites rather than adopted into this environment's state. Azure subscription and tenant IDs are supplied only through `TF_VAR_*` or an ignored `terraform.tfvars` file.

Core planning creates 15 resources across the resource group, VNet/subnet/NSG/public IP, Standard ACR, Cilium AKS, GitHub Actions managed identity/OIDC, and RBAC. Observability and SRE Agent modules are implemented but disabled by default until their dedicated stages.

Every taggable Terraform resource receives `SecurityControl=Ignore`. The verifier runs format/init/validate, Checkov, core and full no-apply plans, and plan JSON tag audits. See [docs/stages/06-terraform-foundation.md](docs/stages/06-terraform-foundation.md).

## Core Azure and AKS

The deployed demo uses deterministic suffix `ij2608`. AKS runs two Ready `Standard_D2ds_v5` Azure Linux 3 nodes with host encryption, managed Entra authentication, Azure RBAC, OIDC/workload identity, and Cilium. The local operator role is opt-in and cluster-scoped; reusable Terraform configurations create no human data-plane assignment by default.

The backend and frontend were built locally for AMD64, pushed to `acrsreagentdemodemoij2608.azurecr.io`, and deployed by digest. Helm release `northstar` runs two replicas of each component in a Restricted namespace with PDBs and NetworkPolicies. Its in-cluster smoke test verifies backend readiness and frontend health.

Connect to the cluster and review the application locally:

```bash
az aks get-credentials \
  --resource-group rg-sre-agent-demo-demo-ij2608 \
  --name aks-sre-agent-demo-demo-ij2608 \
  --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
kubectl port-forward --namespace northstar \
  service/northstar-sre-demo-frontend 8080:8080
```

Open `http://127.0.0.1:8080/`. See [docs/stages/07-core-azure-aks.md](docs/stages/07-core-azure-aks.md).

## Managed Azure Observability

AKS sends managed Prometheus metrics to `amw-sre-agent-demo-demo-ij2608` and cost-scoped Northstar container logs to `log-sre-agent-demo-demo-ij2608`. Selected API server, privileged audit, and authentication logs use resource-specific Log Analytics tables. Managed Grafana 12 is linked to the Azure Monitor workspace.

The backend sends its existing OpenTelemetry server and checkout spans to `appi-sre-agent-demo-demo-ij2608`. AKS workload identity authenticates ingestion with no client secret; the identity receives only `Monitoring Metrics Publisher` on the Application Insights component, whose local authentication is disabled.

Useful queries:

```promql
northstar_build_info
sum by (outcome) (northstar_checkout_attempts_total)
```

```kusto
ContainerLogV2
| where PodNamespace == "northstar"
| extend Payload = parse_json(LogMessage)
| project TimeGenerated,
          OperationId=tostring(Payload.operation_id),
          TraceId=tostring(Payload.trace_id),
          StatusCode=toint(Payload.status_code)
| order by TimeGenerated desc
```

Managed Grafana: `https://amg-sreage-demo-ij2608-gbhdd3bcdeedg2fx.cse.grafana.azure.com`

See [docs/stages/08-managed-observability.md](docs/stages/08-managed-observability.md) for resource names, signal queries, security boundaries, and validation evidence.

## Protected GitHub Delivery

Pull requests to `main` run backend, frontend, and Helm validation and require one approving review from someone other than the last pusher. Stale approvals are dismissed, conversations must be resolved, and administrators cannot bypass the rule.

Deployments are manually dispatched from `main` into the protected `demo` environment. The job authenticates to Azure through the repository's immutable environment-bound OIDC subject, builds AMD64 images on the GitHub-hosted Docker daemon, pushes with Docker, rejects fixed critical vulnerabilities, creates SPDX SBOMs, and deploys only registry digests. `scripts/verify-deployment.sh` proves the release SHA, digests, replicas, workload identity, ServiceMonitor, and in-cluster health.

The first real run blocked a critical frontend OpenSSL CVE before deployment. After patching the runtime packages, [run 31112420552](https://github.com/msftse/sre-agent-demo/actions/runs/31112420552) completed end to end and deployed Helm revision 6.

See [docs/stages/09-protected-github-delivery.md](docs/stages/09-protected-github-delivery.md) for approval rules, workflow steps, OIDC trust, CVE evidence, and deployed digests.
