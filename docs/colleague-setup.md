# Run the Demo from Your Own Fork

## First-time fork callout

If this is your first run in a fresh fork, complete this guide in order without skipping steps. It establishes your local profile, Terraform inputs, GitHub environment values/secrets, workflow permissions, and branch-protection mode expected by the stage scripts.

## Cost warning (read first)

This demo provisions billable Azure services, including AKS, ACR, Log Analytics, Application Insights, Managed Grafana, Functions, Bot Service, Storage, networking, and Azure SRE Agent resources.

- Provision only in a subscription you are allowed to use for this demo.
- Destroy resources when done: `terraform -chdir=iac destroy`.
- Keep Terraform state local and untracked (`iac/terraform.tfstate*`, `*.tfplan`, `iac/terraform.tfvars`).

## Why fork this repository

Use a personal or team fork so you can run the full incident rehearsal with your own GitHub Actions runs, branch protection, webhook configuration, and Azure credentials without changing the canonical maintainer repository.

## Prerequisites (macOS)

Install and sign in before provisioning:

- Azure CLI (`az`)
- GitHub CLI (`gh`)
- Terraform
- Docker Desktop (or equivalent local Docker daemon)
- `jq`
- `kubectl`
- Helm
- Node.js + npm
- `uv` for Python toolchain management

Recommended check:

```bash
./scripts/preflight.sh
```

## Tenant and subscription model

Use the right identifier in the right place:

- Azure subscription ID: where resources are billed and deployed.
- Azure tenant ID (Microsoft Entra): the identity directory backing that Azure subscription context.
- Teams tenant ID: may differ from the Azure tenant; this is used by the Teams bridge validation and routing.

Use GUIDs in scripts and Terraform (not tenant domains).

Quick check:

```bash
az account show --query '{subscriptionId:id,tenantId:tenantId,user:user.name}' -o json
```

## Fork, clone, and upstream remotes

1. Fork the repository in GitHub.
2. Clone your fork locally.
3. Configure `origin` to your fork and `upstream` to the canonical repository.

Example:

```bash
git clone git@github.com:<your-org-or-user>/sre-agent-demo.git
cd sre-agent-demo
git remote add upstream git@github.com:msftse/sre-agent-demo.git
git remote -v
```

The setup scripts validate `origin` and expect `owner/repository` format.

## Authenticate Azure and GitHub

### Azure CLI

```bash
az login
az account set --subscription <subscription-id-or-name>
az account show --query '{subscriptionId:id,tenantId:tenantId,user:user.name}' -o json
```

### GitHub CLI

```bash
gh auth login
gh auth status
gh repo view --json nameWithOwner,viewerPermission
```

You must have `ADMIN` permission on your fork.

## Teams identity inputs

Capture these values before setup:

- Teams tenant ID (GUID)
- Team ID (GUID)
- Channel ID (`19:...@thread.tacv2`)
- Allowed user object ID (GUID)

Use placeholders in notes and scripts; never commit real IDs.

## Generate local profile and tfvars

Run from repository root:

```bash
./scripts/setup-colleague.sh \
  --teams-team-id <teams-team-guid> \
  --teams-channel-id <teams-channel-id-19-thread-tacv2> \
  --teams-user-object-id <allowed-user-object-guid> \
  --owner-email <owner@example.com>
```

Optional flags:

- `--subscription-id <guid>` and `--tenant-id <guid>` to override active Azure CLI context.
- `--teams-tenant-id <guid>` when Teams tenant differs from Azure tenant.
- `--name-suffix <4-8-lowercase-alnum>` for deterministic naming.
- `--output-dir <path>` and `--dry-run` for render checks.
- `--allow-canonical` only for canonical maintainers intentionally targeting `msftse/sre-agent-demo`.

Generated local files:

- `.demo-profile.env`
- `iac/terraform.tfvars`

Security characteristics:

- Both files are mode `0600`.
- Both files are local and git-ignored.
- No PAT, webhook secret, bot secret, or storage key is written there.

## Mandatory preflight and profile validation (immediately after setup)

Run these right after `setup-colleague.sh` and before any Terraform action:

```bash
./scripts/preflight.sh
./scripts/verify-colleague-profile.sh
```

Offline profile validation is available:

```bash
./scripts/verify-colleague-profile.sh --offline
```

## Enable GitHub Actions in your fork

Open your fork settings page and set policy exactly:

1. `Settings` -> `Actions` -> `General`
2. Enable Actions for this repository if prompted.
3. Under `Workflow permissions`, choose `Read and write permissions`.
4. Save.

This repository still enforces least privilege inside workflows via explicit `permissions:` blocks; the repository setting is required for the direct-main incident rehearsal flow.

Baseline check:

```bash
gh workflow list
gh workflow run "Start Demo"
```

## Stage checkpoints before apply

Review these stage contracts before provisioning:

- Stage 6 foundation: [docs/stages/06-terraform-foundation.md](stages/06-terraform-foundation.md)
- Stage 9 protected delivery: [docs/stages/09-protected-github-delivery.md](stages/09-protected-github-delivery.md)

Recommended checkpoint commands:

```bash
./scripts/verify-terraform.sh
```

## Terraform apply and GitHub environment bootstrap

Run:

```bash
terraform -chdir=iac init
terraform -chdir=iac validate
terraform -chdir=iac apply
./scripts/configure-github-environment.sh
./scripts/verify-github-environment.sh
```

`configure-github-environment.sh` resolves repository and environment, creates the environment idempotently, and configures these environment variables:

- `ACR_LOGIN_SERVER`
- `AKS_NAME`
- `AZURE_CLIENT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `RESOURCE_GROUP`
- `TELEMETRY_CLIENT_ID`
- `GRAFANA_URL`

It also configures the environment secret `APPLICATIONINSIGHTS_CONNECTION_STRING`.

`verify-github-environment.sh` validates the environment, required variable names and values, environment secret metadata, and repository-level `STAGE17_GITHUB_TOKEN` metadata.

## Log in to ACR before publishing images

Authenticate Docker to the Terraform-created registry:

```bash
az acr login --name "$(terraform -chdir=iac output -raw acr_login_server | cut -d. -f1)"
```

Then publish images:

```bash
./scripts/publish-images.sh --registry "$(terraform -chdir=iac output -raw acr_login_server)"
```

## Configure branch protection for incident rehearsal

Set incident-demo protection mode:

```bash
./scripts/configure-github-protection.sh incident-demo
```

## Configure Stage 17 token safely (repository-level secret)

Create repository secret in your fork UI:

1. `Settings` -> `Secrets and variables` -> `Actions`
2. `New repository secret`
3. Name: `STAGE17_GITHUB_TOKEN`
4. Value: fine-grained PAT for this fork only

Required fine-grained PAT repository permissions for the direct-main rehearsal flow:

- `Contents`: Read and write
- `Actions`: Read and write
- `Pull requests`: Read
- `Administration`: Read and write (required for branch-protection mode switch)

Store this token only as the Actions repository secret. Never print it in logs or commit it to files.

GitHub PAT documentation:

- <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token>
- <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-fine-grained-personal-access-token>

## Deploy Teams bridge and capability bootstrap

```bash
./scripts/provision-teams-bot-identity.sh
./scripts/deploy-teams-bridge.sh
./scripts/package-teams-app.sh
```

Sideload the generated package into the Team/channel used in setup.

## Live verifiers

```bash
./scripts/verify-containers.sh
./scripts/verify-observability.sh
./scripts/verify-teams-bridge.sh
./scripts/verify-github-connector.sh
./scripts/verify-checkout-skill.sh
./scripts/verify-checkout-response-plan.sh
./scripts/verify-github-continuation.sh
./scripts/verify-deployment.sh
```

## Run the demo end to end

1. Confirm branch protection is `incident-demo`.
2. Trigger `Start Demo` from GitHub Actions.
3. Let Azure SRE Agent investigate and create remediation PR.
4. Perform human review decision (reject or merge).
5. Approve protected deployment when required.
6. Confirm recovery evidence and final RCA in Teams and GitHub.

## Keep your fork synced with upstream

```bash
git fetch upstream
git checkout main
git merge --ff-only upstream/main
git push origin main
```

If fast-forward is not possible, rebase your work branch on updated `main`, resolve conflicts, then rerun relevant verifiers.

## Local state and sensitive-file reminder

Do not commit these local files:

- `.demo-profile.env`
- `iac/terraform.tfvars`
- `iac/terraform.tfstate*`
- `iac/*.tfplan`
