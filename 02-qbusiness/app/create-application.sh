#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-eu-west-1}"
DISPLAY="${DISPLAY:-VaultMesh Knowledge Assistant}"
DESC="${DESC:-Enterprise AI for VaultMesh Technologies}"
IDENTITY_CENTER_ARN="${IDENTITY_CENTER_ARN:-}"
KMS_KEY_ID="${KMS_KEY_ID:-}"

ARGS=( --region "$REGION" --display-name "$DISPLAY" --description "$DESC" )
[[ -n "$IDENTITY_CENTER_ARN" ]] && ARGS+=( --identity-center-instance-arn "$IDENTITY_CENTER_ARN" )
[[ -n "$KMS_KEY_ID" ]] && ARGS+=( --encryption-configuration "kmsKeyId=$KMS_KEY_ID" )

APP_ID=$(aws qbusiness create-application "${ARGS[@]}" --query 'applicationId' --output text)
echo "APP_ID=$APP_ID"

