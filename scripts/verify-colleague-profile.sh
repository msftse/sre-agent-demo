#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT_DIR
readonly DEFAULT_PROFILE_PATH="$ROOT_DIR/.demo-profile.env"
readonly DEFAULT_TFVARS_PATH="$ROOT_DIR/iac/terraform.tfvars"
readonly UUID_PATTERN='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
readonly SUFFIX_PATTERN='^[a-z0-9]{4,8}$'
readonly PROFILE_REPOSITORY_PATTERN='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'
readonly CHANNEL_PATTERN='^19:[^[:space:]]+@thread\.tacv2$'
readonly REQUIRED_PROFILE_VARS=(
  DEMO_SUBSCRIPTION_ID
  DEMO_TENANT_ID
  DEMO_LOCATION
  DEMO_GITHUB_REPOSITORY
  DEMO_GITHUB_REPOSITORY_OWNER_ID
  DEMO_GITHUB_REPOSITORY_ID
  DEMO_GITHUB_ENVIRONMENT
  DEMO_NAME_SUFFIX
  DEMO_TEAMS_TENANT_ID
  DEMO_TEAMS_TEAM_ID
  DEMO_TEAMS_CHANNEL_ID
  DEMO_TEAMS_ALLOWED_USER_OBJECT_ID
  DEMO_TEAMS_PERSONAL_CHAT_ENABLED
  DEMO_TEAMS_PERSONAL_CHAT_ACCESS_MODE
  DEMO_TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR
  DEMO_OWNER_EMAIL
)

# shellcheck source=scripts/lib/repository.sh
source "$ROOT_DIR/scripts/lib/repository.sh"

profile_path="$DEFAULT_PROFILE_PATH"
tfvars_path="$DEFAULT_TFVARS_PATH"
offline=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/verify-colleague-profile.sh [options]

Options:
  --profile <path>  Profile file path (default: .demo-profile.env)
  --tfvars <path>   Terraform tfvars path (default: iac/terraform.tfvars)
  --offline         Skip live Azure/GitHub checks (for render validation)
  -h, --help        Show this message
USAGE
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command is missing: $1"
}

get_mode() {
  local path=$1
  local mode
  if mode=$(stat -f '%Lp' "$path" 2>/dev/null); then
    printf '%s\n' "$mode"
    return 0
  fi
  if mode=$(stat -c '%a' "$path" 2>/dev/null); then
    printf '%s\n' "$mode"
    return 0
  fi
  return 1
}

hcl_string() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '"%s"' "$value"
}

assert_tfvars_line() {
  local expected=$1
  grep -Fx -- "$expected" "$tfvars_path" >/dev/null || fail "Missing tfvars line: $expected"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || fail "Missing value for --profile"
      profile_path=$2
      shift 2
      ;;
    --tfvars)
      [[ $# -ge 2 ]] || fail "Missing value for --tfvars"
      tfvars_path=$2
      shift 2
      ;;
    --offline)
      offline=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

[[ -f "$profile_path" ]] || fail "Profile file not found: $profile_path"
[[ -f "$tfvars_path" ]] || fail "tfvars file not found: $tfvars_path"

profile_mode=$(get_mode "$profile_path") || fail "Unable to read profile permissions"
tfvars_mode=$(get_mode "$tfvars_path") || fail "Unable to read tfvars permissions"
[[ "$profile_mode" == "600" ]] || fail "Profile mode must be 600"
[[ "$tfvars_mode" == "600" ]] || fail "tfvars mode must be 600"

while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || fail "Profile contains invalid assignment syntax"
done <"$profile_path"

# shellcheck disable=SC1090
source "$profile_path"

for key in "${REQUIRED_PROFILE_VARS[@]}"; do
  [[ -n "${!key:-}" ]] || fail "Profile variable is missing or empty: $key"
done

[[ "$DEMO_SUBSCRIPTION_ID" =~ $UUID_PATTERN ]] || fail "DEMO_SUBSCRIPTION_ID must be a UUID"
[[ "$DEMO_TENANT_ID" =~ $UUID_PATTERN ]] || fail "DEMO_TENANT_ID must be a UUID"
[[ "$DEMO_TEAMS_TENANT_ID" =~ $UUID_PATTERN ]] || fail "DEMO_TEAMS_TENANT_ID must be a UUID"
[[ "$DEMO_TEAMS_TEAM_ID" =~ $UUID_PATTERN ]] || fail "DEMO_TEAMS_TEAM_ID must be a UUID"
[[ "$DEMO_TEAMS_ALLOWED_USER_OBJECT_ID" =~ $UUID_PATTERN ]] || fail "DEMO_TEAMS_ALLOWED_USER_OBJECT_ID must be a UUID"
[[ "$DEMO_NAME_SUFFIX" =~ $SUFFIX_PATTERN ]] || fail "DEMO_NAME_SUFFIX must be 4-8 lowercase alphanumeric"
[[ "$DEMO_GITHUB_REPOSITORY" =~ $PROFILE_REPOSITORY_PATTERN ]] || fail "DEMO_GITHUB_REPOSITORY must be owner/repository"
[[ "$DEMO_GITHUB_REPOSITORY_OWNER_ID" =~ ^[0-9]+$ ]] || fail "DEMO_GITHUB_REPOSITORY_OWNER_ID must be numeric"
[[ "$DEMO_GITHUB_REPOSITORY_ID" =~ ^[0-9]+$ ]] || fail "DEMO_GITHUB_REPOSITORY_ID must be numeric"
[[ "$DEMO_TEAMS_CHANNEL_ID" =~ $CHANNEL_PATTERN ]] || fail "DEMO_TEAMS_CHANNEL_ID must match 19:<id>@thread.tacv2"
[[ "$DEMO_TEAMS_PERSONAL_CHAT_ENABLED" == "true" || "$DEMO_TEAMS_PERSONAL_CHAT_ENABLED" == "false" ]] \
  || fail "DEMO_TEAMS_PERSONAL_CHAT_ENABLED must be true or false"
[[ "$DEMO_TEAMS_PERSONAL_CHAT_ACCESS_MODE" == "allowed_user" || "$DEMO_TEAMS_PERSONAL_CHAT_ACCESS_MODE" == "tenant" ]] \
  || fail "DEMO_TEAMS_PERSONAL_CHAT_ACCESS_MODE must be allowed_user or tenant"
[[ "$DEMO_TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR" =~ ^[0-9]+$ ]] \
  || fail "DEMO_TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR must be numeric"
(( DEMO_TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR >= 1 && DEMO_TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR <= 100 )) \
  || fail "DEMO_TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR must be between 1 and 100"
[[ "$DEMO_LOCATION" =~ ^[a-z0-9-]+$ ]] || fail "DEMO_LOCATION must be a location slug"
[[ "$DEMO_GITHUB_ENVIRONMENT" =~ ^[A-Za-z0-9._-]+$ ]] || fail "DEMO_GITHUB_ENVIRONMENT is invalid"

assert_tfvars_line "subscription_id = $(hcl_string "$DEMO_SUBSCRIPTION_ID")"
assert_tfvars_line "tenant_id       = $(hcl_string "$DEMO_TENANT_ID")"
assert_tfvars_line "location        = $(hcl_string "$DEMO_LOCATION")"
assert_tfvars_line "environment     = \"demo\""
assert_tfvars_line "project_name    = \"sre-agent-demo\""
assert_tfvars_line "name_suffix     = $(hcl_string "$DEMO_NAME_SUFFIX")"
assert_tfvars_line "github_repository          = $(hcl_string "$DEMO_GITHUB_REPOSITORY")"
assert_tfvars_line "github_environment         = $(hcl_string "$DEMO_GITHUB_ENVIRONMENT")"
assert_tfvars_line "github_repository_owner_id = $DEMO_GITHUB_REPOSITORY_OWNER_ID"
assert_tfvars_line "github_repository_id       = $DEMO_GITHUB_REPOSITORY_ID"
assert_tfvars_line "enable_observability = true"
assert_tfvars_line "enable_sre_agent     = true"
assert_tfvars_line "enable_teams_bridge  = true"
assert_tfvars_line "teams_tenant_id              = $(hcl_string "$DEMO_TEAMS_TENANT_ID")"
assert_tfvars_line "teams_team_id                = $(hcl_string "$DEMO_TEAMS_TEAM_ID")"
assert_tfvars_line "teams_channel_id             = $(hcl_string "$DEMO_TEAMS_CHANNEL_ID")"
assert_tfvars_line "teams_allowed_user_object_id = $(hcl_string "$DEMO_TEAMS_ALLOWED_USER_OBJECT_ID")"
assert_tfvars_line "teams_personal_chat_enabled        = $DEMO_TEAMS_PERSONAL_CHAT_ENABLED"
assert_tfvars_line "teams_personal_chat_access_mode    = $(hcl_string "$DEMO_TEAMS_PERSONAL_CHAT_ACCESS_MODE")"
assert_tfvars_line "teams_personal_chat_turns_per_hour = $DEMO_TEAMS_PERSONAL_CHAT_TURNS_PER_HOUR"
assert_tfvars_line "  Owner = $(hcl_string "$DEMO_OWNER_EMAIL")"

grep -Fx 'tags = {' "$tfvars_path" >/dev/null || fail "tags block is missing"
grep -Fx '}' "$tfvars_path" >/dev/null || fail "tags block end is missing"

tracked_paths=$(git -C "$ROOT_DIR" ls-files -- ".demo-profile.env" "iac/terraform.tfvars")
[[ -z "$tracked_paths" ]] || fail "Profile or tfvars file must not be tracked by git"

tracked_sensitive=$(git -C "$ROOT_DIR" ls-files -- '*.tfstate' '*.tfstate.*' '*.tfplan')
[[ -z "$tracked_sensitive" ]] || fail "tfstate/tfplan files must not be tracked by git"

if (( offline == 0 )); then
  require_command az
  require_command gh
  require_command jq
  require_command git

  active_subscription=$(az account show --query id -o tsv)
  active_tenant=$(az account show --query tenantId -o tsv)
  [[ "$active_subscription" == "$DEMO_SUBSCRIPTION_ID" ]] || fail "Active Azure subscription does not match profile"
  [[ "$active_tenant" == "$DEMO_TENANT_ID" ]] || fail "Active Azure tenant does not match profile"

  location_count=$(az account list-locations --query "[?name=='$DEMO_LOCATION'] | length(@)" -o tsv)
  [[ "$location_count" == "1" ]] || fail "Profile location is not available in Azure: $DEMO_LOCATION"

  remote_repo=$(require_origin_remote_repository) || fail "Git origin remote must be configured in owner/repository format"
  [[ "$remote_repo" == "$DEMO_GITHUB_REPOSITORY" ]] || fail "Git origin does not match profile repository"

  gh_repo=$(gh repo view --json nameWithOwner,viewerPermission)
  gh_name_with_owner=$(jq -r '.nameWithOwner' <<<"$gh_repo")
  viewer_permission=$(jq -r '.viewerPermission' <<<"$gh_repo")
  [[ "$gh_name_with_owner" == "$DEMO_GITHUB_REPOSITORY" ]] || fail "gh repo view does not match profile repository"
  [[ "$viewer_permission" == "ADMIN" ]] || fail "GitHub ADMIN permission is required"

  repo_json=$(gh api "repos/$DEMO_GITHUB_REPOSITORY")
  owner_id=$(jq -r '.owner.id' <<<"$repo_json")
  repository_id=$(jq -r '.id' <<<"$repo_json")
  [[ "$owner_id" == "$DEMO_GITHUB_REPOSITORY_OWNER_ID" ]] || fail "GitHub owner ID mismatch"
  [[ "$repository_id" == "$DEMO_GITHUB_REPOSITORY_ID" ]] || fail "GitHub repository ID mismatch"
fi

printf 'PASS: colleague profile and tfvars are valid.\n'
printf 'Repository:      %s\n' "$DEMO_GITHUB_REPOSITORY"
printf 'Subscription ID: %s\n' "$DEMO_SUBSCRIPTION_ID"
printf 'Name suffix:     %s\n' "$DEMO_NAME_SUFFIX"
printf 'Teams tenant ID: %s\n' "$DEMO_TEAMS_TENANT_ID"
