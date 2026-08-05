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

Stage 1, repository bootstrap and preflight, is complete. The Azure subscription, Sweden Central service availability and quota, local toolchain, and GitHub access have been validated. No Azure resources have been created.

## Quick Start

Run the repeatable prerequisite check from the repository root:

```bash
./scripts/preflight.sh
```

The script performs read-only Azure and GitHub checks. It expects an authenticated Azure CLI and GitHub CLI session.

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
│       └── README.md
└── scripts/
    └── preflight.sh
```

## Delivery Approach

The demo is built one stage at a time. Each stage starts with an explanation of its purpose and expected changes, and ends with validation, documentation, review, and a scoped commit.

See [docs/stages/README.md](docs/stages/README.md) for the stage map and progress.
