#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly TEMPLATE="$ROOT_DIR/src/teams-bridge/appPackage/manifest.template.json"
readonly OUTPUT_DIR="$ROOT_DIR/.teams-package"
readonly OUTPUT_ZIP="$OUTPUT_DIR/azure-sre-agent.zip"

bot_client_id=""
function_hostname=""

while (( $# > 0 )); do
  case "$1" in
    --bot-client-id)
      bot_client_id=${2:?Missing bot client ID}
      shift 2
      ;;
    --function-hostname)
      function_hostname=${2:?Missing Function hostname}
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

[[ "$bot_client_id" =~ ^[0-9a-fA-F-]{36}$ ]] || {
  printf '%s\n' 'A valid --bot-client-id UUID is required.' >&2
  exit 2
}
[[ "$function_hostname" =~ ^[a-z0-9.-]+\.azurewebsites\.net$ ]] || {
  printf '%s\n' 'A valid --function-hostname is required.' >&2
  exit 2
}

command -v jq >/dev/null 2>&1 || { printf '%s\n' 'jq is required.' >&2; exit 1; }
command -v uv >/dev/null 2>&1 || { printf '%s\n' 'uv is required.' >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { printf '%s\n' 'zip is required.' >&2; exit 1; }

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

jq \
  --arg bot "$bot_client_id" \
  --arg host "$function_hostname" \
  'walk(if type == "string" then gsub("\\$\\{BOT_CLIENT_ID\\}"; $bot) | gsub("\\$\\{FUNCTION_HOSTNAME\\}"; $host) else . end)' \
  "$TEMPLATE" >"$OUTPUT_DIR/manifest.json"

uv run \
  --no-project \
  --index https://packagefeedproxy.microsoft.io/pypi/simple \
  --with pillow \
  python "$ROOT_DIR/scripts/render-teams-icons.py" "$OUTPUT_DIR"

(
  cd "$OUTPUT_DIR"
  zip -q "$OUTPUT_ZIP" manifest.json color.png outline.png
)

printf 'Teams app package: %s\n' "$OUTPUT_ZIP"