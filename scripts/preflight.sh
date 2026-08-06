#!/usr/bin/env bash

set -euo pipefail

readonly TARGET_SUBSCRIPTION="be9948d2-4149-4be2-a040-ef1a6dc1c866"
readonly TARGET_REGION="Sweden Central"
readonly EXPECTED_REMOTE="https://github.com/msftse/sre-agent-demo.git"
readonly REQUIRED_TOOLS=(az docker gh git helm jq kubectl node npm terraform uv)
readonly REQUIRED_PROVIDERS=(
  Microsoft.AlertsManagement
  Microsoft.App
  Microsoft.Authorization
  Microsoft.ContainerRegistry
  Microsoft.ContainerService
  Microsoft.Dashboard
  Microsoft.Insights
  Microsoft.ManagedIdentity
  Microsoft.Monitor
  Microsoft.Network
  Microsoft.OperationalInsights
  Microsoft.PolicyInsights
)
readonly REQUIRED_FEATURES=(
  "Microsoft.Compute|EncryptionAtHost"
)
readonly REGIONAL_RESOURCES=(
  "Microsoft.App|agents"
  "Microsoft.ContainerRegistry|registries"
  "Microsoft.ContainerService|managedClusters"
  "Microsoft.Dashboard|grafana"
  "Microsoft.Insights|components"
  "Microsoft.Monitor|accounts"
  "Microsoft.OperationalInsights|workspaces"
)

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

for tool in "${REQUIRED_TOOLS[@]}"; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required tool is missing: $tool"
done

az account set --subscription "$TARGET_SUBSCRIPTION"
active_subscription=$(az account show --query id -o tsv)
[[ "$active_subscription" == "$TARGET_SUBSCRIPTION" ]] || fail "Unexpected Azure subscription: $active_subscription"

principal_id=$(az ad signed-in-user show --query id -o tsv)
owner_assignments=$(az role assignment list \
  --assignee "$principal_id" \
  --scope "/subscriptions/$TARGET_SUBSCRIPTION" \
  --include-inherited \
  --query "[?roleDefinitionName=='Owner'] | length(@)" \
  -o tsv)
(( owner_assignments > 0 )) || fail "The Azure CLI identity does not inherit Owner on the target subscription"

for provider in "${REQUIRED_PROVIDERS[@]}"; do
  registration_state=$(az provider show --namespace "$provider" --query registrationState -o tsv)
  [[ "$registration_state" == "Registered" ]] || fail "$provider is not registered"
done

for entry in "${REQUIRED_FEATURES[@]}"; do
  namespace=${entry%%|*}
  feature=${entry#*|}
  registration_state=$(az feature show \
    --namespace "$namespace" \
    --name "$feature" \
    --query properties.state \
    -o tsv)
  [[ "$registration_state" == "Registered" ]] || fail "$namespace/$feature is not registered"
done

for entry in "${REGIONAL_RESOURCES[@]}"; do
  provider=${entry%%|*}
  resource_type=${entry#*|}
  is_supported=$(az provider show \
    --namespace "$provider" \
    --query "contains(resourceTypes[?resourceType=='$resource_type'].locations | [0], '$TARGET_REGION')" \
    -o tsv)
  [[ "$is_supported" == "true" ]] || fail "$provider/$resource_type is unavailable in $TARGET_REGION"
done

regional_vcpu_limit=$(az vm list-usage \
  --location swedencentral \
  --query "[?name.value=='cores'].limit | [0]" \
  -o tsv)
regional_vcpu_used=$(az vm list-usage \
  --location swedencentral \
  --query "[?name.value=='cores'].currentValue | [0]" \
  -o tsv)
(( regional_vcpu_limit - regional_vcpu_used >= 4 )) || fail "Fewer than four regional vCPUs are available"

docker info >/dev/null 2>&1 || fail "Docker daemon is unavailable"

remote_url=$(git remote get-url origin)
[[ "$remote_url" == "$EXPECTED_REMOTE" ]] || fail "Unexpected origin URL: $remote_url"

repository=$(gh repo view msftse/sre-agent-demo --json viewerPermission)
[[ $(jq -r '.viewerPermission' <<<"$repository") == "ADMIN" ]] || fail "GitHub ADMIN permission is required"

printf 'PASS: Stage 1 prerequisites are satisfied.\n'
printf 'Azure subscription: %s\n' "$TARGET_SUBSCRIPTION"
printf 'Azure region:       %s\n' "$TARGET_REGION"
printf 'Git remote:         %s\n' "$EXPECTED_REMOTE"
printf 'Available vCPUs:    %s\n' "$((regional_vcpu_limit - regional_vcpu_used))"
