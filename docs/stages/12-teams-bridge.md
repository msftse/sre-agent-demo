# Stage 12: Teams Bridge and Automated SRE Connector

## Goal

Connect Azure SRE Agent to a real Microsoft Teams bot identity for fixed-channel incident updates and optional multi-turn personal conversations without weakening the autonomous incident boundary. Azure SRE Agent receives exactly three Teams notification tools for the fixed channel.

## Architecture

The Teams app uses a single-tenant bot registration in the configured Teams tenant and is sideloaded into the approved Team/channel for messaging-only use. Azure Bot Service forwards Bot Connector activities to a Python 3.12 Azure Functions Flex Consumption app. Durable Functions acknowledges Teams promptly and can continue longer SRE investigations asynchronously.

The Function UAMI calls Azure SRE Agent with audience `https://azuresre.dev`, stores Teams/SRE thread mappings in Azure Table Storage, and reads the bot credential and MCP shared key from Key Vault references. The storage account disables shared keys and anonymous blob access.

Generated names and endpoints change on every recreated environment. Retrieve the current bridge values with:

```bash
terraform -chdir=iac output -json teams_bridge | jq
```

This output includes the Function App name and ID, bot client ID, Key Vault name, UAMI principal ID, messaging endpoint, and MCP endpoint. The storage and Azure Bot resource names are implementation details generated from the deployment suffix. The stable SRE connector name is `northstar-teams`; its fixed destination comes from the `teams_team_id` and `teams_channel_id` Terraform inputs.

## Security Boundary

Inbound Bot Connector JWT validation is owned by the maintained Microsoft Teams SDK. Channel checks require the configured tenant, exact Team GUID, exact channel ID, and operator object ID. Teams activities expose the Microsoft Graph Team GUID as `channelData.team.aadGroupId`; the parser deliberately prefers that field over the Teams thread identifier in `channelData.team.id`.

Personal chat is a separate policy. It is disabled by default and defaults to the configured allowed user. An explicit `tenant` mode permits authenticated users from the configured Teams tenant; each tenant/user/conversation gets an isolated SRE route, one active turn, and a configurable hourly limit. Personal payloads must contain no Team/channel context. Cross-tenant requests and `groupChat` are rejected. This policy never changes the fixed channel used by autonomous notifications.

## Conversational Answer Roundtrip

User-initiated channel and personal turns are separate from autonomous incident timelines:

1. The first authorized at-mention in a Teams channel conversation or an unbound personal message creates an SRE thread.
2. Later at-mentioned messages in that channel conversation and normal personal messages continue the mapped SRE thread. Teams `conversation.id` identifies the channel's top-level reply chain; `replyToId` is retained only as the outbound reply target.
3. Durable Functions polls the SRE messages endpoint every 10 seconds for up to 10 minutes.
4. New complete `SREAgent` messages are returned to the same channel root or personal conversation in lossless, ordered chunks.
5. Pending questions return to Teams and accept another text turn. Approvals remain portal-only. Failure, cancellation, unknown preview states, and timeout return a bounded status with the SRE thread ID.

`status` is side-effect free. Personal `/new` starts a fresh route and `/clear` removes local routing without deleting SRE portal history. Prompts and answer bodies are excluded from Table Storage routing records, Durable orchestration outputs, and routine logs.

Outbound MCP requires `x-mcp-key`, retains DNS-rebinding protection, and allows only the live Function hostname. The server exposes exactly:

- `post_incident_update`
- `reply_incident_thread`
- `get_incident_thread`

For autonomous Azure Monitor incidents, `post_incident_update` resolves the current canonical SRE chat thread from the Azure incident ID. The bridge persists both IDs and returns `sre_thread_id`; the remediation skill uses that value for the hidden PR continuation marker instead of guessing from the alert ID.

No tool can choose another Team/channel, mutate Azure, merge code, or deploy. The Function UAMI has Storage Account Contributor plus Blob/Queue/Table data roles, Key Vault Secrets User, and SRE Agent Standard User. The configured operator has Key Vault Secrets Officer only on this bridge vault for credential rotation.

## Automated Connector Creation

`scripts/configure-sre-teams-connector.sh` creates or updates the `northstar-teams` connector through the SRE Agent data plane. It:

1. Reads the SRE and Teams endpoints from Terraform outputs.
2. Reads `mcp-shared-key` from Key Vault at runtime.
3. Initializes the MCP server and refuses to continue unless its unprefixed tool set is exact.
4. Writes the secret-bearing connector request only to mode-`0600` temporary files.
5. Performs an idempotent `PUT /api/v2/extendedAgent/connectors/northstar-teams`.
6. Reads the connector back and validates endpoint, custom-header authentication, and all three SRE-prefixed tools without printing the credential.
7. Deletes temporary files and unsets tokens on every exit.

`scripts/deploy-teams-bridge.sh` invokes `scripts/configure-sre-agent-capabilities.sh` after Function health succeeds. The bootstrap configures Teams, GitHub, the checkout skill, its responder, and the response plan in dependency order. Connector, skill, responder, and plan creation therefore require no SRE portal work and put no secret in Git or Terraform state. Manual custom-app sideloading into Teams remains the only portal checkpoint because tenant-wide app catalog permissions were intentionally not requested.

## Deployment Lessons

- AzureRM polls new storage accounts with keys, which conflicts with `allowSharedKeyAccess=false`. Storage is therefore owned through AzAPI and its default blob/table services were imported after Azure created them implicitly.
- The live built-in role is `SRE Agent Standard User`, not the earlier documented `SRE Agent User` label.
- Flex Consumption rejects Elastic Premium runtime scale monitoring and legacy worker runtime app settings.
- The provider initially generated a legacy `AzureWebJobsStorage` connection string. It was removed so the host uses the UAMI `AzureWebJobsStorage__*` settings.
- Local Core Tools with Azurite exposed two worker-indexing defects before the successful cloud deployment: the HTTP parameter must be named `req`, and Durable activity binding parameters cannot use parameterized `dict` annotations.

## Verification

Validated after deployment:

```text
Bridge tests: 40 passed
Ruff: passed
mypy strict: passed
Functions: five registered and host Running
Health: HTTP 200, {"status":"ok"}
MCP without key: HTTP 401
MCP with key: exactly three tools
Inbound Teams status mention: ready response received
Outbound MCP: root post, threaded reply, and stored-route read-back succeeded
Incident correlation: Azure incident ID resolved to one canonical SRE thread ID
SRE connector: connected, CustomHeaders, exact three prefixed tools
Terraform: zero drift; tracked count recorded from the current state
Checkout alert instances: 0
Incident traffic: disabled
```

## Outcome

Stage 12 is complete. Teams transport, threading, secure MCP exposure, and automated SRE connector provisioning are ready. Stage 13 subsequently validated the constrained GitHub write capabilities, and the user later completed the architecture proposal with Codex in Stage 18.