# Stage 1: Preflight and Repository Bootstrap

## Goal

Establish a clean repository and prove that the operator, subscription, region, quotas, local tools, and GitHub permissions can support the later implementation stages without creating Azure resources.

## Verified Results

| Check | Result |
| --- | --- |
| Azure subscription | Active subscription matched the deployment input and was enabled |
| Azure CLI identity | Authenticated operator resolved from `az account show` |
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

The Azure CLI and VS Code Azure extensions maintain separate authentication contexts. The CLI is connected to the tenant that owns the target subscription; the extensions may use a different account and tenant. Every deployment command must explicitly verify the CLI subscription before it changes Azure resources; Teams OAuth uses the account selected during its dedicated connector stage.

Retrieve the current account context instead of relying on this stage snapshot:

```bash
az account show --query '{subscription:name,subscriptionId:id,tenantId:tenantId,user:user.name}' -o json
```

## Repeat the Check

```bash
./scripts/preflight.sh
```

The script is read-only. It fails if the active Azure subscription, Owner access, provider registration, Sweden Central support, Docker daemon, configured Git remote, or GitHub administrator permission no longer satisfies the prerequisites.

## Outcome

Stage 1 passed. The repository can proceed to the initial FastAPI backend and React storefront without an Azure provisioning blocker.
