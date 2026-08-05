#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly BACKEND_DIR="$ROOT_DIR/src/backend"
readonly PORT="${SRE_DEMO_VERIFY_PORT:-8001}"
readonly BASE_URL="http://127.0.0.1:$PORT"
readonly TRACE_ID="1234567890abcdef1234567890abcdef"
readonly GIT_SHA=$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)
readonly LOG_FILE=$(mktemp "${TMPDIR:-/tmp}/sre-demo-telemetry.XXXXXX")
readonly HEADERS_FILE=$(mktemp "${TMPDIR:-/tmp}/sre-demo-headers.XXXXXX")
readonly BODY_FILE=$(mktemp "${TMPDIR:-/tmp}/sre-demo-body.XXXXXX")

server_pid=""

cleanup() {
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid"
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -f "$LOG_FILE" "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup EXIT

SRE_DEMO_GIT_SHA="$GIT_SHA" \
SRE_DEMO_IMAGE_DIGEST="local-stage4" \
SRE_DEMO_SERVICE_VERSION="0.1.0" \
SRE_DEMO_TRACE_CONSOLE_EXPORTER="true" \
  "$BACKEND_DIR/.venv/bin/uvicorn" app.main:app \
    --app-dir "$BACKEND_DIR" \
    --host 127.0.0.1 \
    --port "$PORT" >"$LOG_FILE" 2>&1 &
server_pid=$!

curl --retry 20 --retry-connrefused --retry-delay 0 --fail --silent \
  "$BASE_URL/health/ready" >/dev/null

curl --fail --silent --show-error \
  --dump-header "$HEADERS_FILE" \
  --output "$BODY_FILE" \
  --request POST "$BASE_URL/api/checkout" \
  --header "Content-Type: application/json" \
  --header "X-Operation-ID: stage4-confirmed" \
  --header "traceparent: 00-$TRACE_ID-1111111111111111-01" \
  --data '{"email":"observer@example.com","items":[{"product_id":"field-pack-28","quantity":1}]}'

grep -qi '^HTTP/1.1 200' "$HEADERS_FILE"
grep -qi '^x-operation-id: stage4-confirmed' "$HEADERS_FILE"
grep -qi "^x-trace-id: $TRACE_ID" "$HEADERS_FILE"
grep -qi "^x-build-sha: $GIT_SHA" "$HEADERS_FILE"
jq -e '.status == "confirmed" and .totals.total_cents == 16000' "$BODY_FILE" >/dev/null

response_code=$(curl --silent --show-error \
  --output "$BODY_FILE" \
  --write-out '%{http_code}' \
  --request POST "$BASE_URL/api/checkout" \
  --header "Content-Type: application/json" \
  --header "X-Operation-ID: stage4-rejected" \
  --header "traceparent: 00-$TRACE_ID-2222222222222222-01" \
  --data '{"email":"observer@example.com","discount_code":"NOT-A-CODE","items":[{"product_id":"field-pack-28","quantity":1}]}')
[[ "$response_code" == "422" ]]
jq -e '.detail.code == "discount_invalid"' "$BODY_FILE" >/dev/null

release=$(curl --fail --silent "$BASE_URL/api/release")
jq -e --arg git_sha "$GIT_SHA" \
  '.git_sha == $git_sha and .image_digest == "local-stage4"' <<<"$release" >/dev/null

metrics=$(curl --fail --silent "$BASE_URL/metrics")
grep -q 'northstar_checkout_attempts_total{outcome="confirmed"} 1.0' <<<"$metrics"
grep -q 'northstar_checkout_attempts_total{outcome="rejected"} 1.0' <<<"$metrics"
grep -q 'route="/api/checkout",status_code="200"' <<<"$metrics"
grep -q 'route="/api/checkout",status_code="422"' <<<"$metrics"
grep -q "northstar_build_info{environment=\"local\",git_sha=\"$GIT_SHA\"" <<<"$metrics"

grep -q '"operation_id":"stage4-confirmed"' "$LOG_FILE"
grep -q '"operation_id":"stage4-rejected"' "$LOG_FILE"
grep -q "\"trace_id\": \"0x$TRACE_ID\"" "$LOG_FILE"
grep -q '"name": "checkout.calculate"' "$LOG_FILE"
grep -q '"exception.message": "That code is not active."' "$LOG_FILE"

printf 'PASS: local observability signals are correlated.\n'
printf 'Git SHA:  %s\n' "$GIT_SHA"
printf 'Trace ID: %s\n' "$TRACE_ID"
printf 'Metrics:  request, duration, in-progress, checkout outcome, build info\n'
printf 'Evidence: response headers, release JSON, Prometheus, JSON logs, spans\n'
