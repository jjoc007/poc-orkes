#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
INPUT_FILE=${1:-$ROOT_DIR/tasks/samples/pipeline_input.json}

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[pipeline] Missing .env file. Copy .env.sample and fill your values." >&2
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "[pipeline] Input file '$INPUT_FILE' not found." >&2
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
    echo "[pipeline] Required command '$cmd' not found" >&2
    exit 1
  fi
done

get_token() {
  local response token
  echo "[pipeline] Requesting access token"
  response=$(curl -sS -X POST "$ORKES_BASE_URL/oauth/token" \
    -H 'Content-Type: application/json' \
    -d "{\"keyId\":\"$ORKES_KEY\",\"keySecret\":\"$ORKES_SECRET\"}")
  token=$(echo "$response" | jq -r '.access_token // empty')
  if [[ -z "$token" ]]; then
    echo "[pipeline] Unable to obtain token. Response was: $response" >&2
    exit 1
  fi
  echo "$token"
}

main() {
  local payload name version input body token http_code
  payload=$(jq -c '.' "$INPUT_FILE")
  name=$(echo "$payload" | jq -r '.name // ""')
  version=$(echo "$payload" | jq -r '.version // 1')
  input=$(echo "$payload" | jq -c '.input // {}')

  if [[ -z "$name" ]]; then
    echo "[pipeline] Workflow name missing in input file." >&2
    exit 1
  fi

  body=$(jq -n --argjson input "$input" --arg version "$version" '{version: ($version|tonumber), input: $input}')
  token=$(get_token)

  echo "[pipeline] Starting workflow '$name' version $version"
  http_code=$(curl -sS -o /tmp/run_pipeline.out -w '%{http_code}' \
    -X POST "$ORKES_BASE_URL/api/workflow/$name" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $token" \
    -d "$body")
  cat /tmp/run_pipeline.out
  echo
  if [[ $http_code != 2* ]]; then
    echo "[pipeline] Failed to start workflow (HTTP $http_code)" >&2
    exit 1
  fi
  local workflow_id
  workflow_id=$(cat /tmp/run_pipeline.out | jq -r '.workflowId // .')
  echo "[pipeline] Workflow started. ID: $workflow_id"
}

main "$@"
