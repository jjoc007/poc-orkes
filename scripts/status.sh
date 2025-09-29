#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <workflowId>" >&2
  exit 1
fi

WORKFLOW_ID=$1
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[status] Missing .env file. Copy .env.sample and fill your values." >&2
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
    echo "[status] Required command '$cmd' not found" >&2
    exit 1
  fi
done

get_token() {
  local response token
  echo "[status] Requesting access token"
  response=$(curl -sS -X POST "$ORKES_BASE_URL/oauth/token" \
    -H 'Content-Type: application/json' \
    -d "{\"keyId\":\"$ORKES_KEY\",\"keySecret\":\"$ORKES_SECRET\"}")
  token=$(echo "$response" | jq -r '.access_token // empty')
  if [[ -z "$token" ]]; then
    echo "[status] Unable to obtain token. Response was: $response" >&2
    exit 1
  fi
  echo "$token"
}

main() {
  local token http_code
  token=$(get_token)
  echo "[status] Fetching status for $WORKFLOW_ID"
  http_code=$(curl -sS -o /tmp/workflow_status.out -w '%{http_code}' \
    -X GET "$ORKES_BASE_URL/api/workflow/$WORKFLOW_ID" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $token")
  if [[ $http_code != 2* ]]; then
    cat /tmp/workflow_status.out
    echo
    echo "[status] Failed to fetch workflow (HTTP $http_code)" >&2
    exit 1
  fi
  jq '.' /tmp/workflow_status.out
}

main "$@"
