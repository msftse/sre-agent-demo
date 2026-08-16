#!/usr/bin/env bash

set -euo pipefail

readonly REPOSITORY_PATTERN='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'

normalize_repository_from_remote() {
  local remote=$1
  local value

  value=$remote
  value=${value%.git}
  value=${value#git@github.com:}
  value=${value#https://github.com/}
  value=${value#http://github.com/}
  printf '%s\n' "$value"
}

repository_helper_root_dir() {
  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  cd "$script_dir/../.." && pwd
}

repository_helper_iac_dir() {
  printf '%s/iac\n' "$(repository_helper_root_dir)"
}

validate_repository_format() {
  local repository=${1:-}
  [[ "$repository" =~ $REPOSITORY_PATTERN ]]
}

repository_from_origin_remote() {
  local root_dir
  local remote_url
  local repository

  command -v git >/dev/null 2>&1 || return 1
  root_dir=$(repository_helper_root_dir)

  remote_url=$(git -C "$root_dir" remote get-url origin 2>/dev/null) || return 1
  repository=$(normalize_repository_from_remote "$remote_url")
  validate_repository_format "$repository" || return 1

  printf '%s\n' "$repository"
}

require_origin_remote_repository() {
  local repository

  repository=$(repository_from_origin_remote 2>/dev/null || true)
  if [[ -z "$repository" ]]; then
    printf '%s\n' 'Unable to resolve GitHub origin remote in owner/repository format. Configure origin first (for example, git remote set-url origin git@github.com:<owner>/<repo>.git).' >&2
    return 1
  fi

  printf '%s\n' "$repository"
}

repository_from_terraform() {
  local iac_dir
  local value
  iac_dir=$(repository_helper_iac_dir)

  command -v terraform >/dev/null 2>&1 || return 1
  [[ -d "$iac_dir" ]] || return 1

  value=$(terraform -chdir="$iac_dir" output -raw github_repository 2>/dev/null) || return 1
  validate_repository_format "$value" || return 1

  printf '%s\n' "$value"
}

repository_from_gh() {
  local value

  command -v gh >/dev/null 2>&1 || return 1

  value=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) || return 1
  validate_repository_format "$value" || return 1

  printf '%s\n' "$value"
}

repository_from_environment() {
  local value=${GITHUB_REPOSITORY:-}

  validate_repository_format "$value" || return 1
  printf '%s\n' "$value"
}

resolve_repository() {
  local repository

  repository=$(repository_from_environment || true)
  if [[ -z "$repository" ]]; then
    repository=$(repository_from_terraform || true)
  fi
  if [[ -z "$repository" ]]; then
    repository=$(repository_from_origin_remote || true)
  fi
  if [[ -z "$repository" ]]; then
    repository=$(repository_from_gh || true)
  fi

  if [[ -z "$repository" ]] || ! validate_repository_format "$repository"; then
    printf '%s\n' 'Unable to resolve GitHub repository in owner/repository format from the environment, Terraform output, origin remote, or gh repo view.' >&2
    return 1
  fi

  printf '%s\n' "$repository"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  resolve_repository
fi