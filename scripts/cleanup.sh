#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[cleanup] Missing .env file. Copy .env.sample and fill your values." >&2
  exit 1
fi

set -o allexport
# shellcheck disable=SC1090
source "$ENV_FILE"
set +o allexport

: "${ORKES_BASE_URL:?Need ORKES_BASE_URL in .env}"
: "${ORKES_KEY:?Need ORKES_KEY in .env}"
: "${ORKES_SECRET:?Need ORKES_SECRET in .env}"

for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[cleanup] Required command '$cmd' not found" >&2
    exit 1
  fi
done

get_token() {
  local response token
  echo "[cleanup] Requesting access token"
  response=$(curl -sS -X POST "$ORKES_BASE_URL/oauth/token" \
    -H 'Content-Type: application/json' \
    -d "{\"keyId\":\"$ORKES_KEY\",\"keySecret\":\"$ORKES_SECRET\"}")
  token=$(echo "$response" | jq -r '.access_token // empty')
  if [[ -z "$token" ]]; then
    echo "[cleanup] Unable to obtain token. Response was: $response" >&2
    exit 1
  fi
  echo "$token"
}

remove_task() {
  local token=$1
  local task=$2
  echo "[cleanup] Deleting task definition $task"
  curl -sS -X DELETE "$ORKES_BASE_URL/api/metadata/taskdefs/$task" \
    -H "Authorization: Bearer $token" \
    -o /tmp/cleanup_task.out -w ''
  cat /tmp/cleanup_task.out
  echo
}

remove_workflow() {
  local token=$1
  local name=$2
  local version=$3
  echo "[cleanup] Deleting workflow $name v$version"
  curl -sS -X DELETE "$ORKES_BASE_URL/api/metadata/workflow/$name/$version" \
    -H "Authorization: Bearer $token" \
    -o /tmp/cleanup_workflow.out -w ''
  cat /tmp/cleanup_workflow.out
  echo
}

main() {
  local token
  token=$(get_token)
  remove_workflow "$token" "pipeline_simple_v1" 1 || true
  remove_workflow "$token" "deploy_simple_v1" 1 || true
  remove_task "$token" "http_verify" || true
  remove_task "$token" "http_traffic" || true
  remove_task "$token" "http_provision" || true
  echo "[cleanup] Done (errors ignored)."
}

main "$@"
