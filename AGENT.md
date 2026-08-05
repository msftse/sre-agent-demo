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
│       └── README.md
└── scripts/
    └── preflight.sh
```

## Stages

- **Stage 1 - Preflight and repository bootstrap:** Complete
- **Stage 2 - Initial backend and frontend:** Not started
- **Stage 3 - Local application review:** Not started
- **Stages 4-17:** Not started; see `docs/stages/README.md`

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
