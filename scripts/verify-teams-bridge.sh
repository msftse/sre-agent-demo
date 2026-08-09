#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly APP_DIR="$ROOT_DIR/src/teams-bridge"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { printf '%s\n' 'unzip is required.' >&2; exit 1; }
command -v uv >/dev/null 2>&1 || { printf '%s\n' 'uv is required.' >&2; exit 1; }

bash -n \
  "$ROOT_DIR/scripts/configure-sre-teams-connector.sh" \
  "$ROOT_DIR/scripts/deploy-teams-bridge.sh" \
  "$ROOT_DIR/scripts/package-teams-app.sh"

grep -F 'post_incident_update' "$ROOT_DIR/scripts/configure-sre-teams-connector.sh" >/dev/null
grep -F 'reply_incident_thread' "$ROOT_DIR/scripts/configure-sre-teams-connector.sh" >/dev/null
grep -F 'get_incident_thread' "$ROOT_DIR/scripts/configure-sre-teams-connector.sh" >/dev/null
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
    ALLOWED_USER_OBJECT_ID='00000000-0000-0000-0000-000000000004' \
    TEAMS_TENANT_ID='00000000-0000-0000-0000-000000000002' \
    TEAMS_TEAM_ID='00000000-0000-0000-0000-000000000003' \
    TEAMS_CHANNEL_ID='19:test@thread.tacv2' \
    STORAGE_ACCOUNT_NAME='teststorage' \
    STORAGE_TABLE_NAME='teamsbridge' \
    SRE_AGENT_ENDPOINT='https://agent.example' \
    MCP_SHARED_KEY='test-key' \
    uv run python -c '
import function_app
expected = {
    "http_entrypoint",
    "teams_message_orchestrator",
    "persist_teams_activity",
    "start_sre_investigation",
    "reply_with_sre_thread",
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