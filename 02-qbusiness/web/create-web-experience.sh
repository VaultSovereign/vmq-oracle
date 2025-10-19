#!/usr/bin/env bash
set -euo pipefail

APP_ID="${1:-}"
if [[ -z "$APP_ID" ]]; then
  echo "Usage: $0 <APP_ID>" >&2
  exit 1
fi

REGION="${REGION:-eu-west-1}"
TITLE="${TITLE:-VaultMesh-Q-Assistant}"
ROLE_ARN="${ROLE_ARN:-}"

ARGS=(--region "$REGION" --application-id "$APP_ID" --title "$TITLE")
[[ -n "$ROLE_ARN" ]] && ARGS+=(--role-arn "$ROLE_ARN")

WEB_ID=$(aws qbusiness create-web-experience "${ARGS[@]}" --query 'webExperienceId' --output text)

echo "WEB_EXPERIENCE_ID=$WEB_ID"

