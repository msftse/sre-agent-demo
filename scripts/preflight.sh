#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly PROFILE_PATH="$ROOT_DIR/.demo-profile.env"
readonly VERIFY_SCRIPT="$ROOT_DIR/scripts/verify-colleague-profile.sh"
# shellcheck source=scripts/lib/repository.sh
source "$ROOT_DIR/scripts/lib/repository.sh"

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
readonly REQUIRED_PROFILE_VARS=(
  DEMO_SUBSCRIPTION_ID
  DEMO_TENANT_ID
  DEMO_LOCATION
  DEMO_GITHUB_REPOSITORY
  DEMO_GITHUB_REPOSITORY_OWNER_ID
  DEMO_GITHUB_REPOSITORY_ID
  DEMO_GITHUB_ENVIRONMENT
  DEMO_NAME_SUFFIX
  DEMO_TEAMS_TENANT_ID
  DEMO_TEAMS_TEAM_ID
  DEMO_TEAMS_CHANNEL_ID
  DEMO_TEAMS_ALLOWED_USER_OBJECT_ID
  DEMO_OWNER_EMAIL
)

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -f "$PROFILE_PATH" ]] || fail "Missing profile: $PROFILE_PATH"
[[ -f "$VERIFY_SCRIPT" ]] || fail "Missing verifier script: $VERIFY_SCRIPT"

for tool in "${REQUIRED_TOOLS[@]}"; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required tool is missing: $tool"
done

while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || fail "Profile contains invalid assignment syntax"
done <"$PROFILE_PATH"

# shellcheck disable=SC1090
source "$PROFILE_PATH"
for key in "${REQUIRED_PROFILE_VARS[@]}"; do
  [[ -n "${!key:-}" ]] || fail "Profile variable is missing or empty: $key"
done

bash "$VERIFY_SCRIPT"

location_display_name=$(az account list-locations \
  --query "[?name=='$DEMO_LOCATION'].displayName | [0]" \
  -o tsv)
[[ -n "$location_display_name" ]] || fail "Azure location is not recognized: $DEMO_LOCATION"

active_subscription=$(az account show --query id -o tsv)
[[ "$active_subscription" == "$DEMO_SUBSCRIPTION_ID" ]] || fail "Unexpected Azure subscription: $active_subscription"

active_tenant=$(az account show --query tenantId -o tsv)
[[ "$active_tenant" == "$DEMO_TENANT_ID" ]] || fail "Unexpected Azure tenant: $active_tenant"

principal_id=$(az ad signed-in-user show --query id -o tsv)
owner_assignments=$(az role assignment list \
  --assignee "$principal_id" \
  --scope "/subscriptions/$DEMO_SUBSCRIPTION_ID" \
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
  locations_json=$(az provider show \
    --namespace "$provider" \
    --query "resourceTypes[?resourceType=='$resource_type'].locations | [0]" \
    -o json)
  is_supported=$(jq -r --arg location "$(tr '[:upper:]' '[:lower:]' <<<"$location_display_name")" '
      ((map(ascii_downcase) | index($location)) != null)
    ' <<<"$locations_json")
  [[ "$is_supported" == "true" ]] || fail "$provider/$resource_type is unavailable in $location_display_name"
done

regional_vcpu_limit=$(az vm list-usage \
  --location "$DEMO_LOCATION" \
  --query "[?name.value=='cores'].limit | [0]" \
  -o tsv)
regional_vcpu_used=$(az vm list-usage \
  --location "$DEMO_LOCATION" \
  --query "[?name.value=='cores'].currentValue | [0]" \
  -o tsv)
(( regional_vcpu_limit - regional_vcpu_used >= 4 )) || fail "Fewer than four regional vCPUs are available"

docker info >/dev/null 2>&1 || fail "Docker daemon is unavailable"

current_repository=$(resolve_repository)
[[ "$current_repository" == "$DEMO_GITHUB_REPOSITORY" ]] || {
  fail "Resolved repository $current_repository does not match profile repository $DEMO_GITHUB_REPOSITORY"
}

repository=$(gh repo view "$DEMO_GITHUB_REPOSITORY" --json viewerPermission)
[[ $(jq -r '.viewerPermission' <<<"$repository") == "ADMIN" ]] || fail "GitHub ADMIN permission is required"

printf 'PASS: Stage 1 prerequisites are satisfied.\n'
printf 'Azure subscription: %s\n' "$DEMO_SUBSCRIPTION_ID"
printf 'Azure tenant:       %s\n' "$DEMO_TENANT_ID"
printf 'Azure region:       %s (%s)\n' "$DEMO_LOCATION" "$location_display_name"
printf 'Git repository:     %s\n' "$DEMO_GITHUB_REPOSITORY"
printf 'Available vCPUs:    %s\n' "$((regional_vcpu_limit - regional_vcpu_used))"
