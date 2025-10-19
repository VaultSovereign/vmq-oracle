#!/usr/bin/env bash
set -euo pipefail

APP_ID="${1:-}"
if [[ -z "$APP_ID" ]]; then
  echo "Usage: $0 <APP_ID>" >&2
  exit 1
fi

REGION="${REGION:-eu-west-1}"

aws qbusiness update-chat-controls-configuration \
  --region "$REGION" \
  --application-id "$APP_ID" \
  --cli-input-json file://02-qbusiness/guardrails/topic-controls.json

echo "Applied guardrails to application $APP_ID"

