#!/usr/bin/env bash
set -euo pipefail

# Creates/updates the Q Business datasource role (assumed by qbusiness.amazonaws.com)
# and creates managed policies for admin and datasource access from templates.

REGION="${REGION:-eu-west-1}"
ADMIN_POLICY_NAME="${ADMIN_POLICY_NAME:-VaultMeshQBAdminPolicy}"
DATASOURCE_ROLE_NAME="${DATASOURCE_ROLE_NAME:-VaultMeshQBDatasourceRole}"
DATASOURCE_POLICY_NAME="${DATASOURCE_POLICY_NAME:-VaultMeshQBDatasourcePolicy}"

# Optional scoping
APP_ID="${APP_ID:-}"
INDEX_ID="${INDEX_ID:-}"
BUCKET_NAME="${BUCKET_NAME:-}"

ACCOUNT_ID=${ACCOUNT_ID:-$(aws sts get-caller-identity --query 'Account' --output text)}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/.." && pwd)
POLICIES_DIR="${ROOT_DIR}/policies"

echo "Using account: ${ACCOUNT_ID} in ${REGION}"
[[ -z "${BUCKET_NAME}" ]] && echo "BUCKET_NAME not set (used for S3 scope)" >&2 || true

tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

# Render datasource role policy from template
KMS_KEY_ARN_DEFAULT="${KMS_KEY_ARN:-*}"
export BUCKET_NAME ACCOUNT_ID REGION APP_ID INDEX_ID KMS_KEY_ARN=$KMS_KEY_ARN_DEFAULT
envsubst < "${POLICIES_DIR}/qbusiness-datasource-role-policy.tmpl.json" > "${tmpdir}/ds-policy.json"

# Render trust policy; optionally add SourceArn scoping if APP_ID is provided
OPTIONAL_SOURCE_ARN=""
if [[ -n "$APP_ID" ]]; then
  # Best-effort application ARN pattern; if not accepted by IAM, script will fall back without it.
  APP_ARN="arn:aws:qbusiness:${REGION}:${ACCOUNT_ID}:application/${APP_ID}"
  # Inject an additional condition block without escape characters
  OPTIONAL_SOURCE_ARN=",\n        \"ArnLike\": { \"aws:SourceArn\": \"${APP_ARN}\" }"
  # Replace escaped newline with real newline to keep JSON valid
  OPTIONAL_SOURCE_ARN=${OPTIONAL_SOURCE_ARN/\\n/\
}
fi
export OPTIONAL_SOURCE_ARN
envsubst < "${POLICIES_DIR}/qbusiness-datasource-trust-policy.tmpl.json" > "${tmpdir}/trust.json"

# Helper to fetch or create a managed policy from file
ensure_policy() {
  local policy_name="$1"
  local policy_file="$2"
  local arn
  arn=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${policy_name}'] | [0].Arn" --output text)
  if [[ -z "$arn" || "$arn" == "None" ]]; then
    echo "Creating managed policy: $policy_name"
    arn=$(aws iam create-policy \
      --policy-name "$policy_name" \
      --policy-document "file://${policy_file}" \
      --query 'Policy.Arn' --output text)
  else
    echo "Managed policy already exists: $policy_name -> $arn"
  fi
  echo "$arn"
}

ADMIN_POLICY_ARN=$(ensure_policy "$ADMIN_POLICY_NAME" "${POLICIES_DIR}/qbusiness-admin.json")
DATASOURCE_POLICY_ARN=$(ensure_policy "$DATASOURCE_POLICY_NAME" "${tmpdir}/ds-policy.json")

# Create or fetch the datasource role
ROLE_ARN=$(aws iam get-role --role-name "$DATASOURCE_ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || true)
if [[ -z "$ROLE_ARN" ]]; then
  echo "Creating role: ${DATASOURCE_ROLE_NAME}"
  ROLE_ARN=$(aws iam create-role \
    --role-name "$DATASOURCE_ROLE_NAME" \
    --assume-role-policy-document "file://${tmpdir}/trust.json" \
    --query 'Role.Arn' --output text)
else
  echo "Role already exists: $DATASOURCE_ROLE_NAME -> $ROLE_ARN"
  echo "Updating assume-role policy (trust)"
  aws iam update-assume-role-policy --role-name "$DATASOURCE_ROLE_NAME" --policy-document "file://${tmpdir}/trust.json" >/dev/null || true
fi

# Attach datasource policy
HAS_ATTACH=$(aws iam list-attached-role-policies --role-name "$DATASOURCE_ROLE_NAME" \
  --query "AttachedPolicies[?PolicyArn=='${DATASOURCE_POLICY_ARN}'] | length(@)" --output text)
if [[ "$HAS_ATTACH" == "0" ]]; then
  echo "Attaching policy to role: ${DATASOURCE_POLICY_NAME} -> ${DATASOURCE_ROLE_NAME}"
  aws iam attach-role-policy --role-name "$DATASOURCE_ROLE_NAME" --policy-arn "$DATASOURCE_POLICY_ARN" >/dev/null
else
  echo "Policy already attached to role."
fi

echo "DATASOURCE_ROLE_ARN=${ROLE_ARN}"
echo "ADMIN_POLICY_ARN=${ADMIN_POLICY_ARN}"

cat <<EOF

Next steps:
- Ensure S3 bucket in 02-qbusiness/datasources/s3-ds.json matches BUCKET_NAME=${BUCKET_NAME:-<unset>}.
- Use the DATASOURCE_ROLE_ARN when creating the S3 data source (create-s3-ds.sh reads current account automatically).
EOF
