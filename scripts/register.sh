#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[register] Missing .env file. Copy .env.sample and fill your values." >&2
  exit 1
fi

set -o allexport
# shellcheck disable=SC1090
source "$ENV_FILE"
set +o allexport

: "${ORKES_BASE_URL:?Need ORKES_BASE_URL in .env}"
: "${ORKES_KEY:?Need ORKES_KEY in .env}"
: "${ORKES_SECRET:?Need ORKES_SECRET in .env}"
: "${WORKER_BASE_URL:?Need WORKER_BASE_URL in .env}"

for cmd in curl jq python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[register] Required command '$cmd' not found in PATH" >&2
    exit 1
  fi
done

get_token() {
  local response token
  echo "[register] Requesting access token from $ORKES_BASE_URL"
  response=$(curl -sS -X POST "$ORKES_BASE_URL/oauth/token" \
    -H 'Content-Type: application/json' \
    -d "{\"keyId\":\"$ORKES_KEY\",\"keySecret\":\"$ORKES_SECRET\"}")
  token=$(echo "$response" | jq -r '.access_token // empty')
  if [[ -z "$token" ]]; then
    echo "[register] Unable to obtain token. Response was: $response" >&2
    exit 1
  fi
  echo "$token"
}

render_with_worker() {
  python3 - "$1" <<'PY'
import os
import sys

path = sys.argv[1]
base = os.environ.get("WORKER_BASE_URL", "")
with open(path, "r", encoding="utf-8") as fh:
    data = fh.read()
print(data.replace("__WORKER_BASE_URL__", base))
PY
}

register_taskdefs() {
  local token=$1
  echo "[register] Registering task definitions"
  local payload
  payload=$(cat "$ROOT_DIR/tasks/taskdefs.json")
  local http_code
  http_code=$(curl -sS -o /tmp/register_taskdefs.out -w '%{http_code}' \
    -X POST "$ORKES_BASE_URL/api/metadata/taskdefs" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d "$payload")
  cat /tmp/register_taskdefs.out
  echo
  if [[ $http_code != 2* ]]; then
    echo "[register] Failed to register task definitions (HTTP $http_code)" >&2
    exit 1
  fi
}

register_workflow() {
  local token=$1
  local file=$2
  local name
  name=$(basename "$file")
  echo "[register] Registering workflow from $name"
  local rendered
  rendered=$(render_with_worker "$file")
  local http_code
  http_code=$(curl -sS -o /tmp/register_workflow.out -w '%{http_code}' \
    -X POST "$ORKES_BASE_URL/api/metadata/workflow" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d "[$rendered]")
  cat /tmp/register_workflow.out
  echo
  if [[ $http_code != 2* ]]; then
    echo "[register] Failed to register workflow $name (HTTP $http_code)" >&2
    exit 1
  fi
}

main() {
  local token
  token=$(get_token)
  register_taskdefs "$token"
  register_workflow "$token" "$ROOT_DIR/workflows/deploy_simple_v1.json"
  register_workflow "$token" "$ROOT_DIR/workflows/pipeline_simple_v1.json"
  echo "[register] Done."
}

main "$@"
