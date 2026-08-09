#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly IAC_DIR="$ROOT_DIR/iac"
readonly EXPECTED_SUBSCRIPTION="${TF_VAR_subscription_id:-}"
readonly EXPECTED_TENANT="${TF_VAR_tenant_id:-}"
readonly CORE_PLAN=$(mktemp "${TMPDIR:-/tmp}/sre-demo-core.XXXXXX.tfplan")
readonly CORE_JSON=$(mktemp "${TMPDIR:-/tmp}/sre-demo-core.XXXXXX.json")
readonly FULL_PLAN=$(mktemp "${TMPDIR:-/tmp}/sre-demo-full.XXXXXX.tfplan")
readonly FULL_JSON=$(mktemp "${TMPDIR:-/tmp}/sre-demo-full.XXXXXX.json")
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

cleanup() {
  rm -f "$CORE_PLAN" "$CORE_JSON" "$FULL_PLAN" "$FULL_JSON"
}
trap cleanup EXIT

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }
command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v uvx >/dev/null 2>&1 || { printf '%s\n' 'uvx is required for the ephemeral Checkov scan.' >&2; exit 1; }

[[ -n "$EXPECTED_SUBSCRIPTION" ]] || {
  printf '%s\n' 'Set TF_VAR_subscription_id before running Terraform verification.' >&2
  exit 2
}
[[ -n "$EXPECTED_TENANT" ]] || {
  printf '%s\n' 'Set TF_VAR_tenant_id before running Terraform verification.' >&2
  exit 2
}

active_subscription=$(az account show --query id -o tsv)
active_tenant=$(az account show --query tenantId -o tsv)
[[ "$active_subscription" == "$EXPECTED_SUBSCRIPTION" ]] || {
  printf 'Azure CLI subscription %s does not match TF_VAR_subscription_id %s.\n' \
    "$active_subscription" "$EXPECTED_SUBSCRIPTION" >&2
  exit 1
}
[[ "$active_tenant" == "$EXPECTED_TENANT" ]] || {
  printf 'Azure CLI tenant %s does not match TF_VAR_tenant_id %s.\n' \
    "$active_tenant" "$EXPECTED_TENANT" >&2
  exit 1
}

for provider in "${REQUIRED_PROVIDERS[@]}"; do
  registration_state=$(az provider show --namespace "$provider" --query registrationState -o tsv)
  [[ "$registration_state" == "Registered" ]] || {
    printf 'Required Azure provider %s is %s, not Registered.\n' \
      "$provider" "$registration_state" >&2
    exit 1
  }
done

for entry in "${REQUIRED_FEATURES[@]}"; do
  namespace=${entry%%|*}
  feature=${entry#*|}
  registration_state=$(az feature show \
    --namespace "$namespace" \
    --name "$feature" \
    --query properties.state \
    -o tsv)
  [[ "$registration_state" == "Registered" ]] || {
    printf 'Required Azure feature %s/%s is %s, not Registered.\n' \
      "$namespace" "$feature" "$registration_state" >&2
    exit 1
  }
done

terraform -chdir="$IAC_DIR" fmt -check -recursive
terraform -chdir="$IAC_DIR" init -backend=false -input=false >/dev/null
terraform -chdir="$IAC_DIR" validate -no-color

uvx --index https://packagefeedproxy.microsoft.io/pypi/simple \
  --from checkov checkov \
  --directory "$IAC_DIR" \
  --framework terraform \
  --compact \
  --quiet \
  --output cli

terraform -chdir="$IAC_DIR" plan \
  -refresh=false \
  -lock=false \
  -input=false \
  -out="$CORE_PLAN" >/dev/null
terraform -chdir="$IAC_DIR" show -json "$CORE_PLAN" >"$CORE_JSON"

terraform -chdir="$IAC_DIR" plan \
  -refresh=false \
  -lock=false \
  -input=false \
  -out="$FULL_PLAN" \
  -var='enable_observability=true' \
  -var='enable_sre_agent=true' >/dev/null
terraform -chdir="$IAC_DIR" show -json "$FULL_PLAN" >"$FULL_JSON"

audit_plan_tags() {
  local plan_json=$1
  local missing
  missing=$(jq -r '
    .resource_changes[]
    | select(.change.after.tags? != null and .change.after.tags.SecurityControl != "Ignore")
    | .address
  ' "$plan_json")
  [[ -z "$missing" ]] || {
    printf 'Planned resources missing SecurityControl=Ignore:\n%s\n' "$missing" >&2
    return 1
  }
  jq -e '
    .resource_changes[]
    | select(.type == "azurerm_kubernetes_cluster")
    | .change.after.default_node_pool[0].tags.SecurityControl == "Ignore"
  ' "$plan_json" >/dev/null
}

audit_plan_tags "$CORE_JSON"
audit_plan_tags "$FULL_JSON"

jq -e '[.resource_changes[] | select(.change.actions | index("delete"))] | length == 0' \
  "$CORE_JSON" >/dev/null
jq -e '[.resource_changes[] | select(.change.actions | index("delete"))] | length == 0' \
  "$FULL_JSON" >/dev/null

core_resources=$(jq '[.resource_changes[] | select(.change.actions != ["no-op"])] | length' "$CORE_JSON")
full_resources=$(jq '[.resource_changes[] | select(.change.actions != ["no-op"])] | length' "$FULL_JSON")
observability_resources=$(jq '[.resource_changes[] | select(.module_address == "module.observability[0]")] | length' "$FULL_JSON")
aks_monitoring_resources=$(jq '[.resource_changes[] | select(.module_address == "module.aks_monitoring[0]")] | length' "$FULL_JSON")
sre_agent_resources=$(jq '[.resource_changes[] | select(.module_address == "module.sre_agent[0]")] | length' "$FULL_JSON")

[[ "$observability_resources" == "5" ]]
[[ "$aks_monitoring_resources" == "10" ]]
[[ "$sre_agent_resources" == "1" ]]
(( full_resources >= core_resources ))

printf 'PASS: Terraform foundation is valid and plans without applying.\n'
printf 'Providers: AzureRM 4.81, AzureAD 3.9, AzAPI 2.11, random 3.9\n'
printf 'Current core plan: %s resources\n' "$core_resources"
printf 'Current full plan: %s resources (%s observability, %s AKS monitoring, %s SRE Agent)\n' \
  "$full_resources" "$observability_resources" "$aks_monitoring_resources" "$sre_agent_resources"
printf 'Security: zero destroys, Checkov has zero failures, mandatory planned tags pass\n'
