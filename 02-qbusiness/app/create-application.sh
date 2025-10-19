#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-eu-west-1}"
APP_DISPLAY="${APP_DISPLAY:-VaultMesh-Knowledge-Assistant}"
DESC="${DESC:-Enterprise AI for VaultMesh Technologies}"
IDENTITY_CENTER_ARN="${IDENTITY_CENTER_ARN:-}"
KMS_KEY_ID="${KMS_KEY_ID:-}"

ARGS=( --region "$REGION" --display-name "$APP_DISPLAY" --description "$DESC" )
if [[ -n "$IDENTITY_CENTER_ARN" ]]; then
  ARGS+=( --identity-type AWS_IAM_IDC --identity-center-instance-arn "$IDENTITY_CENTER_ARN" )
else
  ARGS+=( --identity-type ANONYMOUS )
fi
[[ -n "$KMS_KEY_ID" ]] && ARGS+=( --encryption-configuration "kmsKeyId=$KMS_KEY_ID" )

APP_ID=$(aws qbusiness create-application "${ARGS[@]}" --query 'applicationId' --output text)
echo "APP_ID=$APP_ID"

