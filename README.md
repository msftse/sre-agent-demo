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

Stage 6 is complete. A modular Terraform foundation now plans the resource group, providers, network, ACR, AKS, GitHub OIDC identity/RBAC, optional observability, and optional Azure SRE Agent. No Terraform apply has run and no Azure resources have been created. Stage 7 will review and apply the core Azure plan after explicit approval.

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

All Terraform files live under `iac/`. State is local and ignored; there is intentionally no `backend.tf`. AzureRM automatic provider registration is disabled and required providers are registered explicitly. Azure subscription and tenant IDs are supplied only through `TF_VAR_*` or an ignored `terraform.tfvars` file.

Core planning creates 27 resources across resource group/provider registration, VNet/subnet/NSG/public IP, Standard ACR, Cilium AKS, GitHub Actions managed identity/OIDC, and RBAC. Observability and SRE Agent modules are implemented but disabled by default until their dedicated stages.

Every taggable Terraform resource receives `SecurityControl=Ignore`. The verifier runs format/init/validate, Checkov, core and full no-apply plans, and plan JSON tag audits. See [docs/stages/06-terraform-foundation.md](docs/stages/06-terraform-foundation.md).
