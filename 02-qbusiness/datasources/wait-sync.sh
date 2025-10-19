#!/usr/bin/env bash
set -euo pipefail

APP_ID="${APP_ID:?APP_ID is required in env}"
INDEX_ID="${INDEX_ID:?INDEX_ID is required in env}"
DS_ID="${DS_ID:?DS_ID is required in env}"
REGION="${REGION:-eu-west-1}"

echo "Waiting for latest sync job on $DS_ID ..."
for i in {1..60}; do
  STATUS="$(aws qbusiness list-data-source-sync-jobs \
    --region "$REGION" \
    --application-id "$APP_ID" \
    --index-id "$INDEX_ID" \
    --data-source-id "$DS_ID" \
    --query 'history[0].status' --output text 2>/dev/null || true)"
  echo "  [$i] status: $STATUS"
  case "$STATUS" in
    SUCCEEDED) exit 0 ;;
    FAILED|STOPPED) echo "Sync failed" >&2; exit 1 ;;
  esac
  sleep 10
done
echo "Timed out waiting for sync" >&2
exit 1

