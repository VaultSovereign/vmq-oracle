#!/usr/bin/env bash
set -euo pipefail

# Accept args or env
APP_ID="${1:-${APP_ID:-}}"
INDEX_ID="${2:-${INDEX_ID:-}}"
DS_ID="${3:-${DS_ID:-}}"
: "${APP_ID:?Set APP_ID env var or pass as arg 1}"
: "${INDEX_ID:?Set INDEX_ID env var or pass as arg 2}"
: "${DS_ID:?Set DS_ID env var or pass as arg 3}"

REGION="${REGION:-eu-west-1}"

aws qbusiness start-data-source-sync-job \
  --region "$REGION" \
  --application-id "$APP_ID" \
  --index-id "$INDEX_ID" \
  --data-source-id "$DS_ID"

echo "Started sync job for data source $DS_ID"
