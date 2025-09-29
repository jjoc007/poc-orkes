#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
INPUT_FILE=${1:-$ROOT_DIR/tasks/samples/deploy_input.json}

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[deploy] Missing .env file. Copy .env.sample and fill your values." >&2
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "[deploy] Input file '$INPUT_FILE' not found." >&2
  exit 1
fi

set -o allexport
# shellcheck disable=SC1090
source "$ENV_FILE"
set +o allexport

: "${CONDUCTOR_BASE_URL:?Need CONDUCTOR_BASE_URL in .env}"

for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[deploy] Required command '$cmd' not found" >&2
    exit 1
  fi
done

# No authentication needed for Conductor standalone
get_token() {
  echo ""
}

main() {
  local payload name version input body token http_code
  payload=$(jq -c '.' "$INPUT_FILE")
  name=$(echo "$payload" | jq -r '.name // ""')
  version=$(echo "$payload" | jq -r '.version // 1')
  input=$(echo "$payload" | jq -c '.input // {}')

  if [[ -z "$name" ]]; then
    echo "[deploy] Workflow name missing in input file." >&2
    exit 1
  fi

  body=$(jq -n --argjson input "$input" --arg version "$version" '{version: ($version|tonumber), input: $input}')
  token=$(get_token)

  echo "[deploy] Starting workflow '$name' version $version"
  http_code=$(curl -sS -o /tmp/run_deploy.out -w '%{http_code}' \
    -X POST "$CONDUCTOR_BASE_URL/api/workflow/$name" \
    -H 'Content-Type: application/json' \
    -d "$body")
  cat /tmp/run_deploy.out
  echo
  if [[ $http_code != 2* ]]; then
    echo "[deploy] Failed to start workflow (HTTP $http_code)" >&2
    exit 1
  fi
  local workflow_id
  workflow_id=$(cat /tmp/run_deploy.out)
  echo "[deploy] Workflow started. ID: $workflow_id"
}

main "$@"
