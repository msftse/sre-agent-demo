#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly IAC_DIR="$ROOT_DIR/iac"
readonly RESPONDER_FILE="$ROOT_DIR/sre-agent-responders/northstar-checkout-responder.md"
readonly RESPONDER_NAME="northstar-checkout-responder"
readonly PLAN_NAME="northstar-checkout-response"
readonly ALERT_TITLE="NorthstarCheckoutFailureRatioHigh"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v shellcheck >/dev/null 2>&1 || { printf '%s\n' 'ShellCheck is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }

bash -n \
  "$ROOT_DIR/scripts/configure-sre-checkout-responder.sh" \
  "$ROOT_DIR/scripts/configure-sre-checkout-response-plan.sh"
shellcheck \
  "$ROOT_DIR/scripts/configure-sre-checkout-responder.sh" \
  "$ROOT_DIR/scripts/configure-sre-checkout-response-plan.sh"

# shellcheck disable=SC2016 # Backticks are literal Markdown in the responder contract.
for clause in \
  'Load and follow the `northstar-checkout-remediation` skill' \
  'Mandatory Teams Timeline' \
  'incident_id` set to the current Azure Monitor incident ID' \
  'do not create a branch, commit, or pull request' \
  'Never approve or merge a pull request' \
  'Awaiting human PR review; no merge or deployment performed.'; do
  grep -F "$clause" "$RESPONDER_FILE" >/dev/null
done

responder_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-responder-verify.XXXXXX")
plan_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-plan-verify.XXXXXX")
filters_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-filters-verify.XXXXXX")
handlers_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-handlers-verify.XXXXXX")
chmod 600 "$responder_file" "$plan_file" "$filters_file" "$handlers_file"

cleanup() {
  unset access_token
  rm -f "$responder_file" "$plan_file" "$filters_file" "$handlers_file"
}
trap cleanup EXIT

sre_endpoint=$(terraform -chdir="$IAC_DIR" output -json sre_agent | jq -er '.endpoint')
access_token=$(az account get-access-token \
  --resource https://azuresre.dev \
  --query accessToken \
  --output tsv)

curl --fail-with-body --silent --show-error --output "$responder_file" \
  --header "Authorization: Bearer $access_token" \
  "${sre_endpoint%/}/api/v2/extendedAgent/agents/$RESPONDER_NAME"
curl --fail-with-body --silent --show-error --output "$plan_file" \
  --header "Authorization: Bearer $access_token" \
  "${sre_endpoint%/}/api/v1/incidentplayground/filters/$PLAN_NAME"
curl --fail-with-body --silent --show-error --output "$filters_file" \
  --header "Authorization: Bearer $access_token" \
  "${sre_endpoint%/}/api/v2/extendedAgent/incidentfilters"
curl --fail-with-body --silent --show-error --output "$handlers_file" \
  --header "Authorization: Bearer $access_token" \
  "${sre_endpoint%/}/api/v2/extendedAgent/incidenthandlers"

jq -e --arg name "$RESPONDER_NAME" --rawfile instructions "$RESPONDER_FILE" '
  .name == $name
  and .type == "ExtendedAgent"
  and .properties.instructions == $instructions
  and .properties.tools == []
  and .properties.enableSkills == true
  and .properties.allowedSkills == ["northstar-checkout-remediation"]
' "$responder_file" >/dev/null

jq -e --arg id "$PLAN_NAME" --arg title "$ALERT_TITLE" --arg responder "$RESPONDER_NAME" '
  .id == $id
  and .priorities == ["Sev1"]
  and .titleContains == $title
  and .isEnabled == true
  and .handlingAgent == $responder
  and .agentMode == "Autonomous"
  and .mergeEnabled == false
' "$plan_file" >/dev/null

jq -e --arg id "$PLAN_NAME" '
  def items: if type == "array" then . else .value end;
  [items[] | select(.name == $id)] | length == 1
' "$filters_file" >/dev/null
jq -e 'if type == "array" then length == 0 else (.value | length == 0) end' "$handlers_file" >/dev/null
jq -e '
  def items: if type == "array" then . else .value end;
  [items[] | select(.name == "quickstart_handler")] | length == 0
' "$filters_file" >/dev/null

printf '%s\n' 'PASS: responder can use only northstar-checkout-remediation; no direct tools assigned.'
printf '%s\n' 'PASS: mandatory Teams timeline and human approval boundaries validated.'
printf '%s\n' 'PASS: active Autonomous plan matches only Sev1 NorthstarCheckoutFailureRatioHigh alerts.'
printf '%s\n' 'PASS: alert merging disabled for repeatable investigations and no quickstart plan exists.'