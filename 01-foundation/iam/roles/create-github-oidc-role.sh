#!/usr/bin/env bash
set -euo pipefail

# Create/Update a GitHub Actions OIDC role for CI to export docs to S3 and trigger Q Business sync.
#
# Required env:
#   BUCKET_NAME   - S3 bucket for approved exports (e.g., vaultmesh-knowledge-base)
#   GITHUB_ORG    - GitHub org/owner (e.g., vaultmesh)
#   GITHUB_REPO   - GitHub repository name (e.g., vm-business-q)
# Optional env:
#   GITHUB_BRANCH - Branch to allow (default: main)
#   REGION        - AWS region (default: eu-west-1)
#   ROLE_NAME     - IAM role name (default: GitHubOIDCRole)
#   POLICY_NAME   - Managed policy name (default: VaultMeshQBGitHubCIPolicy)

REGION="${REGION:-eu-west-1}"
ROLE_NAME="${ROLE_NAME:-GitHubOIDCRole}"
POLICY_NAME="${POLICY_NAME:-VaultMeshQBGitHubCIPolicy}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

for v in BUCKET_NAME GITHUB_ORG GITHUB_REPO; do
  if [[ -z "${!v:-}" ]]; then
    echo "Missing required env: $v" >&2
    exit 1
  fi
done

ACCOUNT_ID=${ACCOUNT_ID:-$(aws sts get-caller-identity --query 'Account' --output text)}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/.." && pwd)
POLICIES_DIR="${ROOT_DIR}/policies"

tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

# Render trust policy
export ACCOUNT_ID GITHUB_ORG GITHUB_REPO GITHUB_BRANCH
envsubst < "${POLICIES_DIR}/github-oidc-trust-policy.tmpl.json" > "${tmpdir}/trust.json"

# Render permissions policy (S3 + Q Business sync)
# Optionally scope CodePipeline permissions to a specific pipeline
# Provide PIPELINE_NAME or AWS_NATIVE_PIPELINE_NAME to narrow scope; otherwise fallback to "*"
PIPELINE_NAME="${PIPELINE_NAME:-${AWS_NATIVE_PIPELINE_NAME:-}}"
if [[ -n "${PIPELINE_NAME}" ]]; then
  CODEPIPELINE_RESOURCE="arn:aws:codepipeline:${REGION}:${ACCOUNT_ID}:${PIPELINE_NAME}"
else
  CODEPIPELINE_RESOURCE="*"
fi

KMS_KEY_ARN_DEFAULT="${KMS_KEY_ARN:-*}"
export BUCKET_NAME CODEPIPELINE_RESOURCE KMS_KEY_ARN=$KMS_KEY_ARN_DEFAULT
envsubst < "${POLICIES_DIR}/github-oidc-qbusiness-ci-policy.tmpl.json" > "${tmpdir}/ci-policy.json"

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
    echo "Creating new policy version from template and setting as default"
    if ! aws iam create-policy-version --policy-arn "$arn" --policy-document "file://${policy_file}" --set-as-default >/dev/null 2>&1; then
      echo "Policy version limit reached, pruning oldest non-default version..."
      # Find oldest non-default version
      OLDEST=$(aws iam list-policy-versions --policy-arn "$arn" \
        --query 'Versions[?IsDefaultVersion==`false`]| sort_by(@,&CreateDate)[0].VersionId' --output text)
      if [[ -n "$OLDEST" && "$OLDEST" != "None" ]]; then
        aws iam delete-policy-version --policy-arn "$arn" --version-id "$OLDEST" >/dev/null
        aws iam create-policy-version --policy-arn "$arn" --policy-document "file://${policy_file}" --set-as-default >/dev/null
      else
        echo "No removable policy versions found; please clean up manually." >&2
      fi
    fi
  fi
  echo "$arn"
}

POLICY_ARN=$(ensure_policy "$POLICY_NAME" "${tmpdir}/ci-policy.json")

# Create or update role
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || true)
if [[ -z "$ROLE_ARN" ]]; then
  echo "Creating role: ${ROLE_NAME}"
  ROLE_ARN=$(aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://${tmpdir}/trust.json" \
    --description "GitHub Actions OIDC role for VaultMesh Q Business CI" \
    --query 'Role.Arn' --output text)
else
  echo "Role already exists: $ROLE_NAME -> $ROLE_ARN"
  echo "Updating assume-role policy (trust)"
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "file://${tmpdir}/trust.json" >/dev/null || true
fi

# Attach policy if not attached
HAS_ATTACH=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" \
  --query "AttachedPolicies[?PolicyArn=='${POLICY_ARN}'] | length(@)" --output text)
if [[ "$HAS_ATTACH" == "0" ]]; then
  echo "Attaching policy to role: ${POLICY_NAME} -> ${ROLE_NAME}"
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN" >/dev/null
else
  echo "Policy already attached to role."
fi

cat <<EOF

ROLE_ARN=${ROLE_ARN}
POLICY_ARN=${POLICY_ARN}

Add this to your GitHub Actions step:

  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${ROLE_ARN}
      aws-region: ${REGION}

Ensure your workflow runs on branch: ${GITHUB_BRANCH}
and repository: ${GITHUB_ORG}/${GITHUB_REPO}

Note:
- This script assumes the OIDC provider exists: arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com
- If not, create it once in your account (AWS Console or CLI) before running this script.
EOF
