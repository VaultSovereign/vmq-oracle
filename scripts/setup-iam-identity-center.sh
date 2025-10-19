#!/usr/bin/env bash
# Set up IAM Identity Center integration for Q Business

set -euo pipefail
cd "$(dirname "$0")/.."

REGION="${REGION:-eu-west-1}"
IDENTITY_CENTER_ARN="arn:aws:sso:::instance/ssoins-6804107edb4ae8eb"

echo "🔐 Setting up IAM Identity Center integration..."

# Create new application with Identity Center
NEW_APP_ID=$(aws qbusiness create-application \
  --region "$REGION" \
  --display-name "VaultMeshKnowledgeAssistantSSO" \
  --description "Enterprise AI for VaultMesh Technologies with SSO" \
  --identity-center-instance-arn "$IDENTITY_CENTER_ARN" \
  --query "applicationId" --output text)

echo "✅ Created new application: $NEW_APP_ID"

# Create index
INDEX_ID=$(aws qbusiness create-index \
  --region "$REGION" \
  --application-id "$NEW_APP_ID" \
  --display-name "vaultmesh-sso-index" \
  --type ENTERPRISE \
  --query "indexId" --output text)

echo "✅ Created index: $INDEX_ID"

# Create retriever
RETRIEVER_ID=$(aws qbusiness create-retriever \
  --region "$REGION" \
  --application-id "$NEW_APP_ID" \
  --type NATIVE_INDEX \
  --display-name "vaultmesh-sso-retriever" \
  --configuration "{\"nativeIndexConfiguration\":{\"indexId\":\"$INDEX_ID\"}}" \
  --query "retrieverId" --output text)

echo "✅ Created retriever: $RETRIEVER_ID"

# Create data source
DS_ID=$(aws qbusiness create-data-source \
  --region "$REGION" \
  --application-id "$NEW_APP_ID" \
  --index-id "$INDEX_ID" \
  --display-name "VaultMeshS3KBSSO" \
  --type "S3" \
  --role-arn "arn:aws:iam::509399262563:role/VaultMeshQBDatasourceRole" \
  --configuration file://02-qbusiness/datasources/s3-ds.json \
  --query "dataSourceId" --output text)

echo "✅ Created data source: $DS_ID"

# Create web experience
WEB_EXPERIENCE_ID=$(aws qbusiness create-web-experience \
  --region "$REGION" \
  --application-id "$NEW_APP_ID" \
  --title "VaultMesh Q Assistant" \
  --query "webExperienceId" --output text)

echo "✅ Created web experience: $WEB_EXPERIENCE_ID"

# Get web URL
WEB_URL=$(aws qbusiness get-web-experience \
  --region "$REGION" \
  --application-id "$NEW_APP_ID" \
  --web-experience-id "$WEB_EXPERIENCE_ID" \
  --query "defaultEndpoint" --output text)

# Update .env with new IDs
cat > .env.sso << EOF
# ---- VaultMesh × Q Business (eu-west-1) with SSO ----
REGION=eu-west-1
ACCOUNT_ID=509399262563

# Data source
BUCKET_NAME=vaultmesh-knowledge-base

# IAM Identity Center
IDENTITY_CENTER_ARN=arn:aws:sso:::instance/ssoins-6804107edb4ae8eb

# Naming (override if desired)
DATASOURCE_ROLE_NAME=VaultMeshQBDatasourceRole
DATASOURCE_POLICY_NAME=VaultMeshQBDatasourcePolicy
ADMIN_POLICY_NAME=VaultMeshQBAdminPolicy

# SSO-enabled application IDs
APP_ID=$NEW_APP_ID
INDEX_ID=$INDEX_ID
RETRIEVER_ID=$RETRIEVER_ID
ROLE_ARN=arn:aws:iam::509399262563:role/VaultMeshQBDatasourceRole
DS_ID=$DS_ID
WEB_EXPERIENCE_ID=$WEB_EXPERIENCE_ID
EOF

echo
echo "🎉 IAM Identity Center setup complete!"
echo "======================================"
echo
echo "📋 New Application Details:"
echo "   App ID: $NEW_APP_ID"
echo "   Index ID: $INDEX_ID"
echo "   Data Source ID: $DS_ID"
echo "   Web Experience ID: $WEB_EXPERIENCE_ID"
echo
echo "🔗 Web Experience URL:"
echo "   $WEB_URL"
echo
echo "📝 Next Steps:"
echo "   1. Copy .env.sso to .env: cp .env.sso .env"
echo "   2. Sync knowledge: make sovereign-sync"
echo "   3. Access web experience (requires AWS SSO login)"
echo
echo "🜄 SSO integration activated!"