#!/usr/bin/env bash

set -euo pipefail

readonly REPOSITORY="msftse/sre-agent-demo"
readonly REQUIRED_CHECK="Validate source and chart"

mode=${1:-}

usage() {
  printf '%s\n' 'Usage: ./scripts/configure-github-protection.sh <routine|incident-demo>'
}

[[ "$mode" == "routine" || "$mode" == "incident-demo" ]] || {
  usage >&2
  exit 2
}

command -v gh >/dev/null 2>&1 || { printf '%s\n' 'GitHub CLI is required.' >&2; exit 1; }

if [[ "$mode" == "incident-demo" ]]; then
  required_status_checks=$(jq -n --arg context "$REQUIRED_CHECK" '{
    strict: true,
    contexts: [$context]
  }')
  required_pull_request_reviews='{
    "dismissal_restrictions": {},
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  }'
  conversation_resolution=true
else
  required_status_checks=null
  required_pull_request_reviews=null
  conversation_resolution=false
fi

jq -n \
  --argjson required_status_checks "$required_status_checks" \
  --argjson required_pull_request_reviews "$required_pull_request_reviews" \
  --argjson conversation_resolution "$conversation_resolution" '
  {
    required_status_checks: $required_status_checks,
    enforce_admins: true,
    required_pull_request_reviews: $required_pull_request_reviews,
    restrictions: null,
    required_linear_history: true,
    allow_force_pushes: false,
    allow_deletions: false,
    block_creations: false,
    required_conversation_resolution: $conversation_resolution,
    lock_branch: false,
    allow_fork_syncing: true
  }
' | gh api \
  --method PUT \
  -H 'Accept: application/vnd.github+json' \
  "repos/$REPOSITORY/branches/main/protection" \
  --input - \
  >/dev/null

printf 'PASS: configured %s GitHub protection mode for %s.\n' "$mode" "$REPOSITORY"