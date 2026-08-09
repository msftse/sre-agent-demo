#!/usr/bin/env bash

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

usage() {
  cat <<'EOF'
Usage:
  provision-teams-bot-identity.sh store-secrets --subscription ID --app-id ID --key-vault NAME
EOF
}

action=${1:-}
[[ -n "$action" ]] || { usage >&2; exit 2; }
shift

subscription=""
app_id=""
key_vault=""

while (( $# > 0 )); do
  case "$1" in
    --subscription) subscription=${2:?}; shift 2 ;;
    --app-id) app_id=${2:?}; shift 2 ;;
    --key-vault) key_vault=${2:?}; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

command -v az >/dev/null 2>&1 || { printf '%s\n' 'Azure CLI is required.' >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { printf '%s\n' 'OpenSSL is required.' >&2; exit 1; }

original_subscription=$(az account show --query id -o tsv)
cleanup() {
  az account set --subscription "$original_subscription" >/dev/null 2>&1 || true
  if [[ -n ${secret_file:-} ]]; then
    rm -f "$secret_file"
  fi
  if [[ -n ${mcp_file:-} ]]; then
    rm -f "$mcp_file"
  fi
}
trap cleanup EXIT

case "$action" in
  store-secrets)
    [[ -n "$subscription" && -n "$app_id" && -n "$key_vault" ]] || {
      usage >&2
      exit 2
    }
    umask 077
    secret_file=$(mktemp "${TMPDIR:-/tmp}/teams-bot-secret.XXXXXX")
    mcp_file=$(mktemp "${TMPDIR:-/tmp}/teams-mcp-key.XXXXXX")

    az account set --subscription "$subscription"
    bot_secret=$(az ad app credential reset \
      --id "$app_id" \
      --append \
      --display-name sre-agent-demo \
      --years 1 \
      --query password \
      --output tsv)
    printf '%s' "$bot_secret" >"$secret_file"
    unset bot_secret

    openssl rand -hex 32 | tr -d '\n' >"$mcp_file"
    az keyvault secret set \
      --vault-name "$key_vault" \
      --name bot-client-secret \
      --file "$secret_file" \
      --query id \
      --output tsv >/dev/null
    az keyvault secret set \
      --vault-name "$key_vault" \
      --name mcp-shared-key \
      --file "$mcp_file" \
      --query id \
      --output tsv >/dev/null
    printf 'Stored bot-client-secret and mcp-shared-key in Key Vault %s.\n' "$key_vault"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac