#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly IAC_DIR="$ROOT_DIR/iac"
readonly SKILL_FILE="$ROOT_DIR/azure-sre-agent/skills/northstar-checkout-remediation.md"
readonly RCA_TEMPLATE_FILE="$ROOT_DIR/azure-sre-agent/response-templates/northstar-checkout-rca.md"
readonly SKILL_NAME="northstar-checkout-remediation"
readonly SKILL_REPOSITORY_PLACEHOLDER="{{GITHUB_REPOSITORY}}"
readonly EXPECTED_TOOLS=(
  RunAzCliReadCommands
  northstar-github_search_code
  northstar-github_get_file_contents
  northstar-github_pull_request_read
  northstar-github_create_branch
  northstar-github_push_files
  northstar-github_create_pull_request
  northstar-github_add_issue_comment
  northstar-teams_post_incident_update
  northstar-teams_reply_incident_thread
  northstar-teams_get_incident_thread
)

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v shellcheck >/dev/null 2>&1 || { printf '%s\n' 'ShellCheck is required.' >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { printf '%s\n' 'Terraform is required.' >&2; exit 1; }
# shellcheck source=scripts/lib/repository.sh
source "$ROOT_DIR/scripts/lib/repository.sh"

count_placeholder_occurrences() {
  local file=$1
  local placeholder=$2

  awk -v placeholder="$placeholder" '
    {
      count += gsub(placeholder, "&")
    }
    END {
      print count + 0
    }
  ' "$file"
}

GITHUB_REPOSITORY=$(resolve_repository)
readonly GITHUB_REPOSITORY

bash -n "$ROOT_DIR/scripts/configure-sre-checkout-skill.sh"
shellcheck -x "$ROOT_DIR/scripts/configure-sre-checkout-skill.sh"

[[ $(sed -n '1p' "$SKILL_FILE") == '---' ]]
[[ $(grep -c '^---$' "$SKILL_FILE") -eq 2 ]]
grep -Fx "name: $SKILL_NAME" "$SKILL_FILE" >/dev/null
[[ -s "$RCA_TEMPLATE_FILE" ]]

placeholder_count=$(count_placeholder_occurrences "$SKILL_FILE" "$SKILL_REPOSITORY_PLACEHOLDER")
[[ "$placeholder_count" -eq 1 ]] || {
  printf 'Skill source must contain exactly one %s placeholder, found %s.\n' \
    "$SKILL_REPOSITORY_PLACEHOLDER" "$placeholder_count" >&2
  exit 1
}

if grep -Eq '(ij[0-9]{4}|/subscriptions/[0-9a-f-]{36}|rg-sre-agent-demo|aks-sre-agent-demo|sre-sre-agent-demo)' "$SKILL_FILE"; then
  printf '%s\n' 'Skill source contains an environment-specific Azure identifier.' >&2
  exit 1
fi

# shellcheck disable=SC2016 # Backticks are literal Markdown in the skill contract.
for discovery_clause in \
  'Never assume an Azure subscription, resource group, AKS cluster' \
  'Run Azure CLI reads serially' \
  'Keep exactly one `RunAzCliReadCommands` call in flight' \
  'Prefer core `az resource`, `az rest`, and `az aks show` commands' \
  'Convert the Log Analytics ARM resource ID to its query identifier' \
  'Pass that customer ID, not the ARM resource ID or workspace name' \
  'query `AppRequests`, `AppDependencies`, and `AppExceptions` through the same Log Analytics customer ID' \
  'Do not declare telemetry query capability unavailable unless at least one correctly formed query' \
  'Resolve the monitored AKS cluster and resource group from those resource IDs' \
  'Resolve linked Log Analytics, Azure Monitor workspace, and Application Insights resource IDs'; do
  grep -F "$discovery_clause" "$SKILL_FILE" >/dev/null
done

for tool in "${EXPECTED_TOOLS[@]}"; do
  grep -Fx "  - $tool" "$SKILL_FILE" >/dev/null
done

# shellcheck disable=SC2016 # Backticks are literal Markdown in the skill contract.
for clause in \
  'Never approve, merge, enable auto-merge, dispatch a workflow, deploy' \
  'Add a regression test for two `field-pack-28` items with `FIELD20`' \
  'helm-field20-recovery-<deployed-git-sha>' \
  'checkout.discount_code == "FIELD20"' \
  'total `23680`' \
  '<!-- sre-thread-id: <current-sre-thread-resource-id> -->' \
  '<!-- teams-thread-id: <current-incident-id> -->' \
  'The SRE marker must be the canonical chat thread resource ID' \
  'not the Azure alert ID or `incidentStatus.incidentId`' \
  'The Teams marker must equal the branch suffix' \
  'Pass the current Azure Monitor incident ID as `incident_id` to every Teams tool' \
  'must resolve through `get_incident_thread`' \
  'an empty auxiliary SRE incident thread is not valid SRE correlation' \
  'wait for the automatic main-only deployment' \
  'starts automatic deployment from the main-only `demo` environment' \
  'After a successful delivery-workflow callback' \
  'Awaiting human PR review; no merge or deployment performed.'; do
  grep -F "$clause" "$SKILL_FILE" >/dev/null
done

for heading in \
  '## Incident Summary' \
  '## Executive Summary' \
  '## Impact' \
  '## Detection' \
  '## Timeline (UTC)' \
  '## Evidence' \
  '## Root Cause' \
  '## Remediation' \
  '## Recovery Validation' \
  '## Follow-up Actions' \
  '## Rollback'; do
  grep -Fx "$heading" "$RCA_TEMPLATE_FILE" >/dev/null
done

skill_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-skill.XXXXXX")
composed_skill_file=$(mktemp "${TMPDIR:-/tmp}/sre-checkout-skill-source.XXXXXX")
chmod 600 "$skill_file"
chmod 600 "$composed_skill_file"

awk -v placeholder="$SKILL_REPOSITORY_PLACEHOLDER" -v repository="$GITHUB_REPOSITORY" '
  {
    gsub(placeholder, repository)
    print
  }
' "$SKILL_FILE" >"$composed_skill_file"

cleanup() {
  unset access_token
  rm -f "$skill_file" "$composed_skill_file"
}
trap cleanup EXIT

sre_endpoint=$(terraform -chdir="$IAC_DIR" output -json sre_agent | jq -er '.endpoint')
access_token=$(az account get-access-token \
  --resource https://azuresre.dev \
  --query accessToken \
  --output tsv)

curl --fail-with-body --silent --show-error \
  --output "$skill_file" \
  --header "Authorization: Bearer $access_token" \
  "${sre_endpoint%/}/api/v2/extendedAgent/skills/$SKILL_NAME"

jq -e \
  --arg name "$SKILL_NAME" \
  --argjson tools "$(printf '%s\n' "${EXPECTED_TOOLS[@]}" | jq -R . | jq -s 'sort')" \
  '
    .name == $name
    and .type == "Skill"
    and ((.properties.tools | sort) == $tools)
    and (.properties.description | type == "string" and length > 0)
  ' "$skill_file" >/dev/null

live_content=$(jq -er '.properties.skillContent' "$skill_file")
expected_content=$(jq -nr \
  --rawfile content "$composed_skill_file" \
  --rawfile rca_template "$RCA_TEMPLATE_FILE" \
  '$content + "\n\n## Bundled RCA Template\n\n" + $rca_template')
[[ "$live_content" == "$expected_content" ]]
grep -F -- "- Repository: \`$GITHUB_REPOSITORY\`" <<<"$live_content" >/dev/null
grep -F "$SKILL_REPOSITORY_PLACEHOLDER" <<<"$live_content" >/dev/null && {
  printf '%s\n' 'Live skill content must not contain the repository placeholder.' >&2
  exit 1
}
unset live_content expected_content

printf '%s\n' 'PASS: skill source front matter and eleven assigned tools validated.'
printf '%s\n' 'PASS: exact FIELD20 repair and regression-test contract validated.'
printf '%s\n' 'PASS: canonical RCA template headings and rendering contract validated.'
printf '%s\n' 'PASS: merge and deployment stop clauses validated.'
printf '%s\n' 'PASS: live Azure SRE Agent skill matches the composed skill and RCA template.'