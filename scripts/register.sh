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

: "${CONDUCTOR_BASE_URL:?Need CONDUCTOR_BASE_URL in .env}"
: "${WORKER_BASE_URL:?Need WORKER_BASE_URL in .env}"

for cmd in curl jq python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[register] Required command '$cmd' not found in PATH" >&2
    exit 1
  fi
done

# No authentication needed for Conductor standalone
get_token() {
  echo ""
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
  echo "[register] Registering task definitions"
  local payload
  payload=$(cat "$ROOT_DIR/tasks/taskdefs.json")
  local http_code
  http_code=$(curl -sS -o /tmp/register_taskdefs.out -w '%{http_code}' \
    -X POST "$CONDUCTOR_BASE_URL/api/metadata/taskdefs" \
    -H "Content-Type: application/json" \
    -d "$payload")
  cat /tmp/register_taskdefs.out
  echo
  if [[ $http_code == 409 ]]; then
    echo "[register] Task definitions already exist, skipping..."
  elif [[ $http_code != 2* ]]; then
    echo "[register] Failed to register task definitions (HTTP $http_code)" >&2
    exit 1
  fi
}

register_workflow() {
  local file=$1
  local name
  name=$(basename "$file")
  echo "[register] Registering workflow from $name"
  local rendered
  rendered=$(render_with_worker "$file")
  local http_code
  http_code=$(curl -sS -o /tmp/register_workflow.out -w '%{http_code}' \
    -X POST "$CONDUCTOR_BASE_URL/api/metadata/workflow" \
    -H "Content-Type: application/json" \
    -d "$rendered")
  cat /tmp/register_workflow.out
  echo
  if [[ $http_code == 409 ]]; then
    echo "[register] Workflow $name already exists, skipping..."
  elif [[ $http_code != 2* ]]; then
    echo "[register] Failed to register workflow $name (HTTP $http_code)" >&2
    exit 1
  fi
}

main() {
  register_taskdefs
  register_workflow "$ROOT_DIR/workflows/deploy_simple_v1.json"
  register_workflow "$ROOT_DIR/workflows/pipeline_simple_v1.json"
  register_workflow "$ROOT_DIR/workflows/finalize_deployment_v1.json"
  register_workflow "$ROOT_DIR/workflows/rollback_deployment_v1.json"
  echo "[register] Done."
}

main "$@"
