#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly IAC_DIR="$ROOT_DIR/iac"
readonly REQUIRED_VARIABLE_NAMES=(
  ACR_LOGIN_SERVER
  AKS_NAME
  AZURE_CLIENT_ID
  AZURE_SUBSCRIPTION_ID
  AZURE_TENANT_ID
  RESOURCE_GROUP
  TELEMETRY_CLIENT_ID
  GRAFANA_URL
)

# shellcheck source=scripts/lib/repository.sh disable=SC1091
source "$ROOT_DIR/scripts/lib/repository.sh"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command is missing: $1"
}

required_output() {
  local outputs_json=$1
  local output_name=$2
  local value

  value=$(jq -er --arg output_name "$output_name" '
    if has($output_name)
      and .[$output_name].value != null
      and (.[$output_name].value | type == "string")
      and (.[$output_name].value | length > 0)
    then .[$output_name].value
    else empty
    end
  ' <<<"$outputs_json" 2>/dev/null) || fail "Terraform output is missing, null, or empty: $output_name"

  printf '%s\n' "$value"
}

required_observability_field() {
  local outputs_json=$1
  local field_name=$2
  local value

  value=$(jq -er --arg field_name "$field_name" '
    if has("observability")
      and .observability.value != null
      and (.observability.value | type == "object")
      and (.observability.value[$field_name] != null)
      and (.observability.value[$field_name] | type == "string")
      and (.observability.value[$field_name] | length > 0)
    then .observability.value[$field_name]
    else empty
    end
  ' <<<"$outputs_json" 2>/dev/null) || fail "Terraform output observability.${field_name} is missing, null, or empty"

  printf '%s\n' "$value"
}

require_command gh
require_command jq
require_command terraform

[[ -d "$IAC_DIR" ]] || fail "Missing iac directory: $IAC_DIR"

repository=$(resolve_repository)
[[ -n "$repository" ]] || fail "Unable to resolve repository"

terraform_outputs=$(terraform -chdir="$IAC_DIR" output -json)

environment=$(required_output "$terraform_outputs" github_environment)
acr_login_server=$(required_output "$terraform_outputs" acr_login_server)
aks_name=$(required_output "$terraform_outputs" aks_name)
azure_client_id=$(required_output "$terraform_outputs" github_actions_client_id)
azure_subscription_id=$(required_output "$terraform_outputs" subscription_id)
azure_tenant_id=$(required_output "$terraform_outputs" tenant_id)
resource_group=$(required_output "$terraform_outputs" resource_group_name)
telemetry_client_id=$(required_observability_field "$terraform_outputs" telemetry_client_id)
grafana_url=$(required_observability_field "$terraform_outputs" grafana_endpoint)
applicationinsights_connection_string=$(required_output "$terraform_outputs" application_insights_connection_string)

gh api --method PUT "repos/$repository/environments/$environment" >/dev/null

gh variable set ACR_LOGIN_SERVER --repo "$repository" --env "$environment" --body "$acr_login_server"
gh variable set AKS_NAME --repo "$repository" --env "$environment" --body "$aks_name"
gh variable set AZURE_CLIENT_ID --repo "$repository" --env "$environment" --body "$azure_client_id"
gh variable set AZURE_SUBSCRIPTION_ID --repo "$repository" --env "$environment" --body "$azure_subscription_id"
gh variable set AZURE_TENANT_ID --repo "$repository" --env "$environment" --body "$azure_tenant_id"
gh variable set RESOURCE_GROUP --repo "$repository" --env "$environment" --body "$resource_group"
gh variable set TELEMETRY_CLIENT_ID --repo "$repository" --env "$environment" --body "$telemetry_client_id"
gh variable set GRAFANA_URL --repo "$repository" --env "$environment" --body "$grafana_url"

printf '%s' "$applicationinsights_connection_string" | gh secret set APPLICATIONINSIGHTS_CONNECTION_STRING \
  --repo "$repository" \
  --env "$environment"
unset applicationinsights_connection_string

environment_variables_json=$(gh api "repos/$repository/environments/$environment/variables?per_page=100")
for variable_name in "${REQUIRED_VARIABLE_NAMES[@]}"; do
  jq -e --arg variable_name "$variable_name" '
    [.variables[]?.name] | index($variable_name) != null
  ' <<<"$environment_variables_json" >/dev/null || fail "Missing environment variable after configuration: $variable_name"
done

environment_secret_metadata=$(gh api "repos/$repository/environments/$environment/secrets/APPLICATIONINSIGHTS_CONNECTION_STRING")
jq -e '
  .name == "APPLICATIONINSIGHTS_CONNECTION_STRING"
  and (.updated_at | type == "string" and length > 0)
' <<<"$environment_secret_metadata" >/dev/null || fail "Environment secret metadata verification failed"

printf 'PASS: configured GitHub environment variables and secret for %s (%s).\n' "$repository" "$environment"
