#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly RESPONDER_FILE="$ROOT_DIR/azure-sre-agent/subagents/sre-agent-responders/northstar-checkout-responder.md"
readonly RESPONDER_NAME="northstar-checkout-responder"
readonly RESPONDER_DESCRIPTION="Handles NorthstarCheckoutFailureRatioHigh incidents with the checkout remediation skill and a mandatory Teams timeline."
readonly ALLOWED_SKILL="northstar-checkout-remediation"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }
[[ -f "$RESPONDER_FILE" ]] || { printf 'Responder source not found: %s\n' "$RESPONDER_FILE" >&2; exit 1; }

agent_output=$(terraform -chdir="$ROOT_DIR/iac" output -json sre_agent)
agent_id=$(jq -er '.id' <<<"$agent_output")
sre_endpoint=$(jq -er '.endpoint' <<<"$agent_output")
subscription_id=$(jq -nr --arg id "$agent_id" '$id | split("/")[2] | select(length > 0)')
active_subscription=$(az account show --query id --output tsv)

[[ "$active_subscription" == "$subscription_id" ]] || {
  printf 'Azure CLI subscription mismatch: expected %s from Terraform.\n' "$subscription_id" >&2
  exit 1
}

request_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-responder-request.XXXXXX")
response_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-responder-response.XXXXXX")
responder_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-responder-current.XXXXXX")
chmod 600 "$request_file" "$response_file" "$responder_file"

cleanup() {
  unset access_token
  rm -f "$request_file" "$response_file" "$responder_file"
}
trap cleanup EXIT

jq -n \
  --arg name "$RESPONDER_NAME" \
  --arg description "$RESPONDER_DESCRIPTION" \
  --rawfile instructions "$RESPONDER_FILE" \
  --arg skill "$ALLOWED_SKILL" \
  '{
    name: $name,
    type: "ExtendedAgent",
    properties: {
      handoffDescription: $description,
      instructions: $instructions,
      tools: [],
      handoffs: [],
      enableSkills: true,
      allowedSkills: [$skill]
    }
  }' >"$request_file"

access_token=$(az account get-access-token \
  --resource https://azuresre.dev \
  --query accessToken \
  --output tsv)
responder_url="${sre_endpoint%/}/api/v2/extendedAgent/agents/$RESPONDER_NAME"

http_code=$(curl --silent --show-error --max-time 60 \
  --output "$response_file" \
  --write-out '%{http_code}' \
  --request PUT \
  --header "Authorization: Bearer $access_token" \
  --header 'Content-Type: application/json' \
  --data-binary "@$request_file" \
  "$responder_url")

[[ "$http_code" == "200" || "$http_code" == "201" || "$http_code" == "202" ]] || {
  printf 'SRE Agent responder create/update failed with HTTP %s.\n' "$http_code" >&2
  jq -r '.error.message // .detail // .message // empty' "$response_file" >&2 || true
  exit 1
}

curl --fail-with-body --silent --show-error \
  --output "$responder_file" \
  --header "Authorization: Bearer $access_token" \
  "$responder_url"

jq -e \
  --arg name "$RESPONDER_NAME" \
  --arg skill "$ALLOWED_SKILL" \
  '
    .name == $name
    and .properties.tools == []
    and .properties.enableSkills == true
    and (.properties.allowedSkills == [$skill])
  ' "$responder_file" >/dev/null

printf 'Azure SRE Agent responder configured: %s\n' "$RESPONDER_NAME"
printf 'Allowed skill: %s\n' "$ALLOWED_SKILL"