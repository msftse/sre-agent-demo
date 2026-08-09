#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly PLAN_NAME="northstar-checkout-response"
readonly RESPONDER_NAME="northstar-checkout-responder"
readonly ALERT_TITLE="NorthstarCheckoutFailureRatioHigh"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }

agent_output=$(terraform -chdir="$ROOT_DIR/iac" output -json sre_agent)
agent_id=$(jq -er '.id' <<<"$agent_output")
sre_endpoint=$(jq -er '.endpoint' <<<"$agent_output")
subscription_id=$(jq -nr --arg id "$agent_id" '$id | split("/")[2] | select(length > 0)')
active_subscription=$(az account show --query id --output tsv)

[[ "$active_subscription" == "$subscription_id" ]] || {
  printf 'Azure CLI subscription mismatch: expected %s from Terraform.\n' "$subscription_id" >&2
  exit 1
}

request_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-plan-request.XXXXXX")
response_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-plan-response.XXXXXX")
responder_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-plan-responder.XXXXXX")
chmod 600 "$request_file" "$response_file" "$responder_file"

cleanup() {
  unset access_token
  rm -f "$request_file" "$response_file" "$responder_file"
}
trap cleanup EXIT

access_token=$(az account get-access-token \
  --resource https://azuresre.dev \
  --query accessToken \
  --output tsv)

curl --fail-with-body --silent --show-error \
  --output "$responder_file" \
  --header "Authorization: Bearer $access_token" \
  "${sre_endpoint%/}/api/v2/extendedAgent/agents/$RESPONDER_NAME"

jq -e \
  --arg name "$RESPONDER_NAME" \
  '.name == $name and .properties.allowedSkills == ["northstar-checkout-remediation"]' \
  "$responder_file" >/dev/null

jq -n \
  --arg id "$PLAN_NAME" \
  --arg title "$ALERT_TITLE" \
  --arg responder "$RESPONDER_NAME" \
  '{
    id: $id,
    priorities: ["Sev1"],
    titleContains: $title,
    isEnabled: true,
    handlingAgent: $responder,
    agentMode: "Autonomous",
    mergeEnabled: true,
    mergeWindowHours: 3
  }' >"$request_file"

plan_url="${sre_endpoint%/}/api/v1/incidentplayground/filters/$PLAN_NAME"
current_http_code=$(curl --silent --show-error --max-time 30 \
  --output /dev/null \
  --write-out '%{http_code}' \
  --header "Authorization: Bearer $access_token" \
  "$plan_url")

case "$current_http_code" in
  200) request_method="POST" ;;
  404) request_method="PUT" ;;
  *)
    printf 'Unable to determine response plan state; GET returned HTTP %s.\n' "$current_http_code" >&2
    exit 1
    ;;
esac

http_code=$(curl --silent --show-error --max-time 60 \
  --output "$response_file" \
  --write-out '%{http_code}' \
  --request "$request_method" \
  --header "Authorization: Bearer $access_token" \
  --header 'Content-Type: application/json' \
  --data-binary "@$request_file" \
  "$plan_url")

[[ "$http_code" == "200" || "$http_code" == "201" || "$http_code" == "202" ]] || {
  printf 'SRE Agent response plan create/update failed with HTTP %s.\n' "$http_code" >&2
  if jq -e . "$response_file" >/dev/null 2>&1; then
    jq -r 'if type == "string" then . else (.error.message // .detail // .message // empty) end' "$response_file" >&2 || true
  else
    sed -n '1,8p' "$response_file" >&2
  fi
  exit 1
}

jq -e \
  --arg id "$PLAN_NAME" \
  --arg title "$ALERT_TITLE" \
  --arg responder "$RESPONDER_NAME" \
  '
    .id == $id
    and .priorities == ["Sev1"]
    and .titleContains == $title
    and .isEnabled == true
    and .handlingAgent == $responder
    and .agentMode == "Autonomous"
    and .mergeEnabled == true
    and .mergeWindowHours == 3
  ' "$response_file" >/dev/null

printf 'Azure SRE Agent response plan configured: %s\n' "$PLAN_NAME"
printf 'Match: Sev1 title contains %s\n' "$ALERT_TITLE"
printf 'Responder: %s (Autonomous)\n' "$RESPONDER_NAME"