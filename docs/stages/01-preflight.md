# Stage 1: Preflight and Repository Bootstrap

## Goal

Establish a clean repository and prove that the operator, subscription, region, quotas, local tools, and GitHub permissions can support the later implementation stages without creating Azure resources.

## Verified Results

| Check | Result |
| --- | --- |
| Azure subscription | `ME-MngEnvMCAP786446-itzhakjanach-1` (`be9948d2-4149-4be2-a040-ef1a6dc1c866`), enabled |
| Azure CLI identity | `itzhakjanach@MngEnvMCAP786446.onmicrosoft.com` |
| Azure authorization | Inherited `Owner` at management-group scope |
| Required providers | Registered |
| Preferred region | Sweden Central supports every planned resource type |
| Compute quota | 98 of 100 regional vCPUs free; 100 DSv5-family vCPUs free |
| Network quota | 998 public IP addresses and 999 virtual networks free |
| GitHub identity | `ij-23` |
| GitHub repository access | `ADMIN`; repository confirmed empty before configuring `origin` |
| Docker | Client and server available |
| Terraform | 1.15.3 |
| kubectl | 1.35.1 |
| Helm | 4.2.3 |
| Node.js and npm | 24.13.1 and 11.8.0 |
| Python | System Python is 3.9.6; Python 3.12 will be provisioned with `uv` in Stage 2 |

## Regional Resource Types

The following Azure resource types report Sweden Central support:

- `Microsoft.App/agents`
- `Microsoft.ContainerService/managedClusters`
- `Microsoft.Dashboard/grafana`
- `Microsoft.Monitor/accounts`
- `Microsoft.Insights/components`
- `Microsoft.OperationalInsights/workspaces`
- `Microsoft.ContainerRegistry/registries`

## Authentication Boundary

The Azure CLI and VS Code Azure extensions maintain separate authentication contexts. The CLI is connected to the managed-environment tenant that owns the target subscription. VS Code Azure extensions are signed in as `itzhakjanach@microsoft.com` in the Microsoft tenant. Every deployment command must explicitly verify the CLI subscription before it changes Azure resources; Teams OAuth will use the Microsoft account during its dedicated connector stage.

## Repeat the Check

```bash
./scripts/preflight.sh
```

The script is read-only. It fails if the active Azure subscription, Owner access, provider registration, Sweden Central support, Docker daemon, configured Git remote, or GitHub administrator permission no longer satisfies the prerequisites.

## Outcome

Stage 1 passed. The repository can proceed to the initial FastAPI backend and React storefront without an Azure provisioning blocker.
