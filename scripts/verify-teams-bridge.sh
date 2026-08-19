#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly APP_DIR="$ROOT_DIR/src/teams-bridge"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { printf '%s\n' 'unzip is required.' >&2; exit 1; }
command -v uv >/dev/null 2>&1 || { printf '%s\n' 'uv is required.' >&2; exit 1; }

bash -n \
  "$ROOT_DIR/scripts/configure-github-environment.sh" \
  "$ROOT_DIR/scripts/configure-sre-agent-capabilities.sh" \
  "$ROOT_DIR/scripts/configure-sre-checkout-responder.sh" \
  "$ROOT_DIR/scripts/configure-sre-checkout-response-plan.sh" \
  "$ROOT_DIR/scripts/configure-sre-checkout-skill.sh" \
  "$ROOT_DIR/scripts/configure-github-webhook.sh" \
  "$ROOT_DIR/scripts/configure-sre-github-connector.sh" \
  "$ROOT_DIR/scripts/configure-sre-teams-connector.sh" \
  "$ROOT_DIR/scripts/deploy-teams-bridge.sh" \
  "$ROOT_DIR/scripts/package-teams-app.sh" \
  "$ROOT_DIR/scripts/verify-checkout-response-plan.sh" \
  "$ROOT_DIR/scripts/verify-checkout-skill.sh" \
  "$ROOT_DIR/scripts/verify-github-environment.sh" \
  "$ROOT_DIR/scripts/verify-github-continuation.sh"

capability_bootstrap="$ROOT_DIR/scripts/configure-sre-agent-capabilities.sh"
teams_line=$(grep -nF 'configure-sre-teams-connector.sh' "$capability_bootstrap" | cut -d: -f1)
github_line=$(grep -nF 'configure-sre-github-connector.sh' "$capability_bootstrap" | cut -d: -f1)
skill_line=$(grep -nF 'configure-sre-checkout-skill.sh' "$capability_bootstrap" | cut -d: -f1)
responder_line=$(grep -nF 'configure-sre-checkout-responder.sh' "$capability_bootstrap" | cut -d: -f1)
plan_line=$(grep -nF 'configure-sre-checkout-response-plan.sh' "$capability_bootstrap" | cut -d: -f1)
(( teams_line < github_line && github_line < skill_line && skill_line < responder_line && responder_line < plan_line ))
grep -F 'configure-sre-agent-capabilities.sh' "$ROOT_DIR/scripts/deploy-teams-bridge.sh" >/dev/null
grep -F -- '--setting-names AzureWebJobsStorage' "$ROOT_DIR/scripts/deploy-teams-bridge.sh" >/dev/null
grep -F 'Legacy AzureWebJobsStorage setting remains after publish.' "$ROOT_DIR/scripts/deploy-teams-bridge.sh" >/dev/null
if grep -F 'configure-sre-teams-connector.sh' "$ROOT_DIR/scripts/deploy-teams-bridge.sh" >/dev/null; then
  printf '%s\n' 'Deployment bypasses the unified SRE capability bootstrap.' >&2
  exit 1
fi

grep -F 'post_incident_update' "$ROOT_DIR/scripts/configure-sre-teams-connector.sh" >/dev/null
grep -F 'reply_incident_thread' "$ROOT_DIR/scripts/configure-sre-teams-connector.sh" >/dev/null
grep -F 'get_incident_thread' "$ROOT_DIR/scripts/configure-sre-teams-connector.sh" >/dev/null
grep -F 'post_incident_update(incident_id: str' "$ROOT_DIR/src/teams-bridge/bridge/runtime.py" >/dev/null
grep -F 'get_incident_thread(incident_id: str' "$ROOT_DIR/src/teams-bridge/bridge/runtime.py" >/dev/null
grep -F 'find_thread_by_incident_id' "$ROOT_DIR/src/teams-bridge/bridge/sre_client.py" >/dev/null
grep -F '"SreThreadId": request["sre_thread_id"]' "$ROOT_DIR/src/teams-bridge/bridge/state.py" >/dev/null
grep -F '"TeamsThreadId": teams_thread_id' "$ROOT_DIR/src/teams-bridge/bridge/state.py" >/dev/null
# shellcheck disable=SC2016 # This is literal jq interpolation syntax in the connector script.
grep -F '"\($connector)_" + .' "$ROOT_DIR/scripts/configure-sre-teams-connector.sh" >/dev/null

(
  cd "$APP_DIR"
  uv sync --locked --all-groups
  uv run ruff check . "$ROOT_DIR/scripts/render-teams-icons.py"
  uv run mypy bridge
  uv run pytest -q

  CLIENT_ID='00000000-0000-0000-0000-000000000001' \
    CLIENT_SECRET='test-only' \
    TENANT_ID='00000000-0000-0000-0000-000000000002' \
    GITHUB_REPOSITORY='colleague/sre-agent-demo' \
    ALLOWED_USER_OBJECT_ID='00000000-0000-0000-0000-000000000004' \
    TEAMS_TENANT_ID='00000000-0000-0000-0000-000000000002' \
    TEAMS_TEAM_ID='00000000-0000-0000-0000-000000000003' \
    TEAMS_CHANNEL_ID='19:test@thread.tacv2' \
    STORAGE_ACCOUNT_NAME='teststorage' \
    STORAGE_TABLE_NAME='teamsbridge' \
    SRE_AGENT_ENDPOINT='https://agent.example' \
    MCP_SHARED_KEY='test-key' \
    GITHUB_WEBHOOK_SECRET='webhook-secret' \
    uv run python -c '
import function_app
expected = {
  "complete_sre_turn",
  "fail_sre_turn",
    "http_entrypoint",
  "poll_sre_turn",
  "teams_chat_turn_orchestrator",
    "teams_message_orchestrator",
    "persist_teams_activity",
    "start_sre_investigation",
    "reply_with_sre_thread",
  "timeout_sre_turn",
}
actual = {item.get_function_name() for item in function_app.app.get_functions()}
assert actual == expected, actual
'
)

"$ROOT_DIR/scripts/package-teams-app.sh" \
  --bot-client-id '00000000-0000-0000-0000-000000000001' \
  --function-hostname 'func-test.azurewebsites.net' >/dev/null

unzip -t "$ROOT_DIR/.teams-package/azure-sre-agent.zip" >/dev/null
jq -e '
  .id == "00000000-0000-0000-0000-000000000001"
  and .bots[0].botId == .id
  and .validDomains == ["func-test.azurewebsites.net"]
' "$ROOT_DIR/.teams-package/manifest.json" >/dev/null

printf 'PASS: Teams bridge source, Functions registration, tests, and app package are valid.\n'
printf 'PASS: Azure incident IDs resolve to canonical SRE thread IDs for durable PR correlation.\n'