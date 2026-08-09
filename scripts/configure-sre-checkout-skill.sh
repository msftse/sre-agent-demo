#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly SKILL_FILE="$ROOT_DIR/sre-agent-skills/northstar-checkout-remediation.md"
readonly SKILL_NAME="northstar-checkout-remediation"
readonly SKILL_DESCRIPTION="Use for Northstar checkout HTTP 5xx incidents, FIELD20 discount failures, discount_calculation_failed errors, or the NorthstarCheckoutFailureRatioHigh alert on AKS."
readonly EXPECTED_TOOLS=(
  RunAzCliReadCommands
  northstar-github_search_code
  northstar-github_get_file_contents
  northstar-github_create_branch
  northstar-github_push_files
  northstar-github_create_pull_request
  northstar-teams_post_incident_update
  northstar-teams_reply_incident_thread
  northstar-teams_get_incident_thread
)

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }
[[ -f "$SKILL_FILE" ]] || { printf 'Skill source not found: %s\n' "$SKILL_FILE" >&2; exit 1; }

agent_output=$(terraform -chdir="$ROOT_DIR/iac" output -json sre_agent)
agent_id=$(jq -er '.id' <<<"$agent_output")
sre_endpoint=$(jq -er '.endpoint' <<<"$agent_output")
subscription_id=$(jq -nr --arg id "$agent_id" '$id | split("/")[2] | select(length > 0)')
active_subscription=$(az account show --query id --output tsv)

[[ "$active_subscription" == "$subscription_id" ]] || {
  printf 'Azure CLI subscription mismatch: expected %s from Terraform.\n' "$subscription_id" >&2
  exit 1
}

request_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-skill-request.XXXXXX")
response_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-skill-response.XXXXXX")
chmod 600 "$request_file" "$response_file"

cleanup() {
  unset access_token
  rm -f "$request_file" "$response_file"
}
trap cleanup EXIT

tools_json=$(printf '%s\n' "${EXPECTED_TOOLS[@]}" | jq -R . | jq -s .)
jq -n \
  --arg name "$SKILL_NAME" \
  --arg description "$SKILL_DESCRIPTION" \
  --rawfile content "$SKILL_FILE" \
  --argjson tools "$tools_json" \
  '{
    name: $name,
    type: "Skill",
    properties: {
      description: $description,
      skillContent: $content,
      tools: $tools,
      additionalFiles: []
    }
  }' >"$request_file"

access_token=$(az account get-access-token \
  --resource https://azuresre.dev \
  --query accessToken \
  --output tsv)

http_code=$(curl --silent --show-error --max-time 60 \
  --output "$response_file" \
  --write-out '%{http_code}' \
  --request PUT \
  --header "Authorization: Bearer $access_token" \
  --header 'Content-Type: application/json' \
  --data-binary "@$request_file" \
  "${sre_endpoint%/}/api/v2/extendedAgent/skills/$SKILL_NAME")

[[ "$http_code" == "200" || "$http_code" == "201" || "$http_code" == "202" ]] || {
  printf 'SRE Agent skill create/update failed with HTTP %s.\n' "$http_code" >&2
  exit 1
}

printf 'Azure SRE Agent skill configured: %s\n' "$SKILL_NAME"
printf 'Source: %s\n' "${SKILL_FILE#"$ROOT_DIR/"}"