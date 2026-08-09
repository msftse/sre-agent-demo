# Stage 12: Teams Bridge and Automated SRE Connector

## Goal

Connect Azure SRE Agent to a real Microsoft Teams bot identity for bidirectional, threaded incident updates without activating the dormant checkout incident. The bridge must accept only the approved operator, Team, and channel, and Azure SRE Agent must receive exactly three Teams notification tools.

## Architecture

The Teams app uses a single-tenant bot registration in the demo tenant and is sideloaded into the Microsoft corporate Team for messaging-only use. Azure Bot Service forwards Bot Connector activities to a Python 3.12 Azure Functions Flex Consumption app. Durable Functions acknowledges Teams promptly and can continue longer SRE investigations asynchronously.

The Function UAMI calls Azure SRE Agent with audience `https://azuresre.dev`, stores Teams/SRE thread mappings in Azure Table Storage, and reads the bot credential and MCP shared key from Key Vault references. The storage account disables shared keys and anonymous blob access.

| Component | Live value |
| --- | --- |
| Function App | `func-tm-sreagent-demo-ij2608` |
| Azure Bot | `bot-teams-sre-agent-demo-demo-ij2608` (F0) |
| Bot endpoint | `https://func-tm-sreagent-demo-ij2608.azurewebsites.net/api/messages` |
| MCP endpoint | `https://func-tm-sreagent-demo-ij2608.azurewebsites.net/api/mcp/` |
| Key Vault | `kv-tm-sreagent-ij2608` |
| Storage | `sttmsreagentdemoij2608` |
| SRE connector | `northstar-teams` |
| Target | Team `276a314b-c2c8-4363-b044-edf802d82193`, channel `IJ-Test` |

## Security Boundary

Inbound Bot Connector JWT validation is owned by the maintained Microsoft Teams SDK. Application checks additionally require the corporate tenant, exact Team GUID, exact channel ID, and operator object ID. Teams activities expose the Microsoft Graph Team GUID as `channelData.team.aadGroupId`; the parser deliberately prefers that field over the Teams thread identifier in `channelData.team.id`.

Outbound MCP requires `x-mcp-key`, retains DNS-rebinding protection, and allows only the live Function hostname. The server exposes exactly:

- `post_incident_update`
- `reply_incident_thread`
- `get_incident_thread`

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
Bridge tests: 13 passed
Ruff: passed
mypy strict: passed
Functions: five registered and host Running
Health: HTTP 200, {"status":"ok"}
MCP without key: HTTP 401
MCP with key: exactly three tools
Inbound Teams status mention: ready response received
Outbound MCP: root post, threaded reply, and stored-route read-back succeeded
SRE connector: connected, CustomHeaders, exact three prefixed tools
Terraform: 62 resources, zero drift
Checkout alert instances: 0
Incident traffic: disabled
```

## Outcome

Stage 12 is complete. Teams transport, threading, secure MCP exposure, and automated SRE connector provisioning are ready. Stage 13 subsequently validated the constrained GitHub write capabilities; the user will create the final architecture proposal with Codex in Stage 18.