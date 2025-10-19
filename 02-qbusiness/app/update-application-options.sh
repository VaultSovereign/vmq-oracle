#!/usr/bin/env bash
set -euo pipefail

# Optional convenience to update application options like Identity Center ARN or KMS.
# Usage: APP_ID=... [IDENTITY_CENTER_ARN=...] [KMS_KEY_ID=...] ./update-application-options.sh

REGION="${REGION:-eu-west-1}"
APP_ID="${APP_ID:-}"
IDENTITY_CENTER_ARN="${IDENTITY_CENTER_ARN:-}"
KMS_KEY_ID="${KMS_KEY_ID:-}"

if [[ -z "$APP_ID" ]]; then
  echo "APP_ID is required" >&2
  exit 1
fi

ARGS=( --region "$REGION" --application-id "$APP_ID" )
[[ -n "$IDENTITY_CENTER_ARN" ]] && ARGS+=( --identity-center-instance-arn "$IDENTITY_CENTER_ARN" )
[[ -n "$KMS_KEY_ID" ]] && ARGS+=( --encryption-configuration "kmsKeyId=$KMS_KEY_ID" )

aws qbusiness update-application "${ARGS[@]}" >/dev/null
echo "Updated application $APP_ID"

