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
- `kubelogin`
- Helm
- Node.js + npm
- `uv` for Python toolchain management
- Azure Functions Core Tools v4 (`func`)
- ShellCheck
- OpenSSL and `zip`

Install the CLI prerequisites with Homebrew:

```bash
brew tap hashicorp/tap
brew tap azure/functions
brew tap Azure/kubelogin
brew install azure-cli gh hashicorp/tap/terraform jq kubernetes-cli Azure/kubelogin/kubelogin helm node uv shellcheck
brew install azure/functions/azure-functions-core-tools@4
brew install --cask docker
```

If Homebrew asks you to trust a vendor tap, review the prompt and follow your organization’s package policy. Start Docker Desktop before preflight. Git, OpenSSL, `curl`, `zip`, and Python 3 are commonly available through macOS or developer tools; install any missing command before continuing.

Confirm the commands and Docker daemon are available. The full `preflight.sh` check runs after profile generation because it requires `.demo-profile.env`.

```bash
for tool in az docker func gh helm jq kubectl kubelogin node npm openssl shellcheck terraform uv zip; do
  command -v "$tool" >/dev/null || printf 'Missing tool: %s\n' "$tool"
done
docker info >/dev/null
```

## Tenant and subscription model

Use the right identifier in the right place:

- Azure subscription ID: where resources are billed and deployed.
- Azure tenant ID (Microsoft Entra): the identity directory backing that Azure subscription context.
- Teams tenant ID: may differ from the Azure tenant; this is used by the Teams bridge validation and routing.

The single-tenant bot application is created in the Azure deployment tenant (`tenant_id`). `teams_tenant_id` identifies the tenant whose Teams activities the bridge accepts. The original demo has proven these can differ, but each colleague must use values they are authorized to administer.

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

### Teams tenant ID

If Teams uses the same tenant as the active Azure subscription:

```bash
az account show --query tenantId -o tsv
```

If Teams uses another tenant, copy its **Tenant ID** from **Microsoft Entra admin center > Identity > Overview**, or ask the Teams tenant administrator. Use the GUID, not a domain such as `example.onmicrosoft.com`.

### Team ID and channel ID from Teams

In the Teams client:

1. Select the `...` menu next to the Team and choose **Get link to team**. The `groupId=<guid>` query value is the Team ID.
2. Select the `...` menu next to the colleague-specific channel and choose **Get link to channel**. In current links, the URL-encoded value after `/l/channel/` and before the next `/` is the channel ID. Some link formats expose the same value as `threadId`. After URL decoding, it has the form `19:...@thread.tacv2`.

URL-decode a copied channel value on macOS or Linux with:

```bash
python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' \
  '<url-encoded-channel-id>'
```

### Team ID and channel ID with Microsoft Graph

When Azure CLI is authenticated to the Teams tenant, list joined Teams:

```bash
az rest \
  --method GET \
  --url 'https://graph.microsoft.com/v1.0/me/joinedTeams' \
  --query 'value[].{name:displayName,id:id}' \
  -o table
```

After selecting the Team ID, list its channels:

```bash
TEAM_ID='<team-guid>'
az rest \
  --method GET \
  --url "https://graph.microsoft.com/v1.0/teams/$TEAM_ID/channels" \
  --query 'value[].{name:displayName,id:id,membershipType:membershipType}' \
  -o table
```

Use the exact returned channel ID; do not replace or remove punctuation.

### Allowed user object ID

The allowed user is the colleague permitted to start inbound investigations from Teams. While authenticated to the Teams tenant, run:

```bash
az ad signed-in-user show --query id -o tsv
```

If Teams uses a different tenant from the Azure subscription, preserve the Azure subscription, authenticate to the Teams tenant long enough to collect the values, and then restore the Azure context:

```bash
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az login --tenant '<teams-tenant-guid>' --allow-no-subscriptions

az ad signed-in-user show --query id -o tsv
az rest --method GET \
  --url 'https://graph.microsoft.com/v1.0/me/joinedTeams' \
  --query 'value[].{name:displayName,id:id}' \
  -o table

az account set --subscription "$AZURE_SUBSCRIPTION_ID"
```

Confirm the original Azure subscription is active again before setup:

```bash
az account show --query '{subscriptionId:id,tenantId:tenantId,user:user.name}' -o json
```

Use placeholders in notes and scripts; never commit real IDs. **Each colleague must use a unique Teams channel.** The Teams tenant and parent Team may be shared, but reusing one channel across deployments mixes incident timelines and makes ownership ambiguous.

## One deployment per fork

This repository supports one active Azure deployment per fork. The GitHub `demo` environment, environment-bound OIDC trust, webhook, secrets, branch protection, `main` history, and Teams bridge are repository-wide. Do not use `--name-suffix` to create parallel environments in one fork; use a second fork for a second simultaneous deployment. The `github_environment` value is intentionally fixed to `demo`.

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
- `--enable-teams-personal-chat` to allow 1:1 conversations; disabled by default.
- `--teams-personal-chat-access-mode <allowed_user|tenant>` to restrict personal chat to the configured user (default) or all authenticated users in the configured Teams tenant.
- `--teams-personal-chat-turns-per-hour <1-100>` for the per-user personal-chat cost/abuse limit (default `10`).
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
- Channel authorization always remains locked to the configured tenant, Team, channel, and allowed user. Personal tenant mode does not relax that channel boundary.
- Personal routes are isolated by tenant, user, and conversation. Group chats and cross-tenant requests are rejected.

## Mandatory preflight and profile validation (immediately after setup)

Run these right after `setup-colleague.sh` and before any Terraform action:

```bash
./scripts/preflight.sh
./scripts/verify-colleague-profile.sh
```

Run `preflight.sh` first: it checks required tools and invokes the profile verifier. The explicit second command is a readable checkpoint and should also pass.

Offline profile validation is available:

```bash
./scripts/verify-colleague-profile.sh --offline
```

## Enable GitHub Actions in your fork

Open your fork settings page and set policy exactly:

1. `Settings` -> `Actions` -> `General`
2. Enable Actions for this repository if prompted.
3. Under `Workflow permissions`, choose `Read repository contents permission`.
4. Leave `Allow GitHub Actions to create and approve pull requests` disabled.
5. Save.

Workflows request any additional permissions explicitly. The direct-main incident rehearsal uses the separately scoped `STAGE17_GITHUB_TOKEN`; it does not require write access from the default workflow token.

Baseline check:

```bash
gh workflow list
gh workflow view start-demo.yml
gh workflow view deliver-demo.yml
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

Provisioning commonly takes 20–40 minutes. Before deploying the bridge, confirm the SRE Agent reports `Succeeded` and its data plane answers:

```bash
SRE_AGENT=$(terraform -chdir=iac output -json sre_agent)
SRE_AGENT_ID=$(jq -r '.id' <<<"$SRE_AGENT")
SRE_AGENT_ENDPOINT=$(jq -r '.endpoint' <<<"$SRE_AGENT")
az resource show --ids "$SRE_AGENT_ID" --api-version 2026-01-01 \
  --query properties.provisioningState -o tsv
SRE_TOKEN=$(az account get-access-token --resource https://azuresre.dev \
  --query accessToken -o tsv)
curl --fail --silent --show-error \
  --header "Authorization: Bearer $SRE_TOKEN" \
  "${SRE_AGENT_ENDPOINT%/}/api/v1/threads" | jq 'length'
unset SRE_TOKEN
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
SUBSCRIPTION_ID=$(terraform -chdir=iac output -raw subscription_id)
TEAMS_BRIDGE=$(terraform -chdir=iac output -json teams_bridge)
BOT_APP_ID=$(jq -r '.bot_client_id' <<<"$TEAMS_BRIDGE")
KEY_VAULT=$(jq -r '.key_vault_name' <<<"$TEAMS_BRIDGE")

./scripts/provision-teams-bot-identity.sh store-secrets \
  --subscription "$SUBSCRIPTION_ID" \
  --app-id "$BOT_APP_ID" \
  --key-vault "$KEY_VAULT"
./scripts/deploy-teams-bridge.sh
```

`deploy-teams-bridge.sh` packages the Teams app and configures the Teams/GitHub connectors, checkout skill, responder, response plan, and signed GitHub webhook. Do not run `package-teams-app.sh` separately.

Sideload `.teams-package/azure-sre-agent.zip` through **Teams > Apps > Manage your apps > Upload an app > Upload a custom app**, choose **Add to a team**, and select the configured Team. In the configured channel, send `@Azure SRE Agent status`; the bot should report that the bridge is ready. If upload is disabled, contact the Teams tenant administrator.

If personal chat is enabled, open the app from **Teams > Apps** and send `status` without mentioning the bot. Normal personal messages create or continue that user's active SRE thread. `/new` starts a fresh thread (`/new <question>` starts it immediately), and `/clear` removes local routing without deleting portal history. Channel follow-ups must at-mention the bot; personal messages do not. Answers are returned in ordered parts for up to 10 minutes per turn. Questions requiring SRE approval are shown in Teams, but approval or rejection remains in the SRE Agent portal.

## Live verifiers

```bash
./scripts/verify-teams-bridge.sh
./scripts/verify-github-connector.sh
./scripts/verify-checkout-skill.sh
./scripts/verify-checkout-response-plan.sh
./scripts/verify-github-continuation.sh
```

These checks validate the Function/package, connector allowlists, composed skill and RCA template, responder/response plan, and signed continuation webhook. `verify-containers.sh` and `verify-observability.sh` are local-development gates; `verify-deployment.sh` is called by the delivery workflow with exact image digests and is not a standalone no-argument check.

## Run the demo end to end

Before the customer joins, confirm the healthy baseline, `2/2` application replicas, no traffic generator, Teams `status` response, passing control-plane verifiers, no open PR, no active delivery, and `incident-demo` branch protection.

1. Trigger **Start Demo** in GitHub Actions and enable its confirmation checkbox; false confirmation skips the job.
2. Allow several minutes for incident delivery, two one-minute alert windows, and the SRE investigation.
3. Follow Teams evidence and review the generated remediation PR.
4. Merge the PR when ready. Recovery deployment is automatic; this demo has no separate environment-review approval.
5. Confirm the deployed merge SHA, healthy replicas, successful FIELD20 checkout, and absent traffic generator.
6. Allow the five-minute alert auto-resolution window before expecting the final Teams and PR RCA.

After a successful recovery, wait for alert resolution, no open PR, idle delivery, and a completed RCA before running **Start Demo** again. No manual Table Storage cleanup is required.

Troubleshooting map:

- Workflow configuration: `./scripts/verify-github-environment.sh`
- Teams transport: `./scripts/verify-teams-bridge.sh`
- GitHub tools: `./scripts/verify-github-connector.sh`
- Skill/responder/plan: `./scripts/verify-checkout-skill.sh` and `./scripts/verify-checkout-response-plan.sh`
- Webhook continuation: `./scripts/verify-github-continuation.sh`
- Alert signal: Azure Monitor alert `NorthstarCheckoutFailureRatioHigh` and the `northstar-sre-demo-traffic` deployment

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

## Teardown and cleanup

Destroy the deployment after the demo:

```bash
RESOURCE_GROUP=$(terraform -chdir=iac output -raw resource_group_name)
terraform -chdir=iac destroy
az group exists --name "$RESOURCE_GROUP"
```

The group-existence command must return `false`. Azure may temporarily report asynchronous deletion or subnet-in-use errors. Wait for platform cleanup and rerun `terraform destroy`; do not delete entries from Terraform state to suppress the error. Verify the resource group is gone, remove the custom Teams app when no longer needed, revoke the fine-grained PAT, and remove the fork’s demo secrets. Stopping Azure SRE Agent does not stop its always-on charge; deletion does.
