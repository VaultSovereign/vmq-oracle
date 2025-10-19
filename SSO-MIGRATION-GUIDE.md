# SSO Migration Guide - Anonymous → IAM Identity Center

**Current State:** ANONYMOUS (identityType: "ANONYMOUS")
**Target State:** AWS IAM Identity Center (identityType: "AWS_IAM_IDC")
**Application:** VaultMesh-Knowledge-Assistant (33b247da-92e9-42f4-a03e-892b28b51c21)
**Estimated Time:** 2-3 hours
**Risk:** Medium (requires app reconfiguration)

---

## Overview

The Q Business application is currently in **ANONYMOUS** mode, which allows:
- ✓ Basic guardrails (blocked phrases)
- ✓ Action invocations with default groups
- ✗ Topic controls (requires SSO)
- ✗ Response scope filtering (requires SSO)
- ✗ Group-based content access (requires SSO)

**After SSO migration, you unlock:**
- ✓ Full topic controls (credentials, confidential-business-info)
- ✓ Response scope: `ENTERPRISE_CONTENT_ONLY`
- ✓ Group-scoped content filtering
- ✓ Real user attribution in logs
- ✓ Persona auto-resolution from groups

---

## Prerequisites

### 1. AWS IAM Identity Center Setup

**Check if Identity Center is enabled:**
```bash
aws sso-admin list-instances --region eu-west-1
```

**If not enabled:**
```bash
# Enable via AWS Console:
# 1. Go to IAM Identity Center
# 2. Enable in eu-west-1
# 3. Configure your identity source (AWS Managed Microsoft AD, Okta, etc.)
```

### 2. User Groups Created

Ensure these groups exist in Identity Center:
- `VaultMesh-Engineering`
- `VaultMesh-Delivery`
- `VaultMesh-Compliance`
- `VaultMesh-Management`

**List groups:**
```bash
IDENTITY_STORE_ID=$(aws sso-admin list-instances --region eu-west-1 --query 'Instances[0].IdentityStoreId' --output text)
aws identitystore list-groups --identity-store-id $IDENTITY_STORE_ID --region eu-west-1
```

### 3. Users Assigned to Groups

At least one test user per group for validation.

---

## Migration Path: Two Options

### Option A: Update Existing Application (Preferred)

**Pros:**
- Keep existing application ID
- No need to update retriever, web experience
- Faster migration

**Cons:**
- Not all Q Business apps support identity type change
- May require AWS support ticket

**Steps:**

#### 1. Create Q Business Application in Identity Center

```bash
# Get Identity Center instance ARN
INSTANCE_ARN=$(aws sso-admin list-instances --region eu-west-1 --query 'Instances[0].InstanceArn' --output text)

# Create application
aws sso-admin create-application \
  --application-provider-arn arn:aws:sso::aws:applicationProvider/custom \
  --instance-arn $INSTANCE_ARN \
  --name "VaultMesh Q Business" \
  --description "RUBEDO Actions with SSO" \
  --status ENABLED \
  --region eu-west-1

# Note the ApplicationArn output
```

#### 2. Attempt to Update Q Business Application

```bash
# Try updating identity type
aws qbusiness update-application \
  --application-id 33b247da-92e9-42f4-a03e-892b28b51c21 \
  --identity-type AWS_IAM_IDC \
  --iam-identity-provider-arn <identity-center-app-arn> \
  --region eu-west-1
```

**If this fails:** Proceed to Option B (create new app).

#### 3. Verify Update

```bash
aws qbusiness get-application \
  --application-id 33b247da-92e9-42f4-a03e-892b28b51c21 \
  --region eu-west-1 \
  --query '{IdentityType, IamIdentityProviderArn}'
```

Expected:
```json
{
  "IdentityType": "AWS_IAM_IDC",
  "IamIdentityProviderArn": "arn:aws:sso::...:application/..."
}
```

---

### Option B: Create New Application with SSO (Guaranteed)

**Pros:**
- Clean slate
- Guaranteed to work
- Full SSO configuration from start

**Cons:**
- New application ID
- Must update retriever, web experience
- Slightly longer migration

**Steps:**

#### 1. Backup Current Configuration

```bash
# Save current app details
aws qbusiness get-application \
  --application-id 33b247da-92e9-42f4-a03e-892b28b51c21 \
  --region eu-west-1 > /tmp/old-app-config.json

# Save retriever details
aws qbusiness get-retriever \
  --application-id 33b247da-92e9-42f4-a03e-892b28b51c21 \
  --retriever-id 07742e35-7209-40d9-bb9d-6e190c4558f7 \
  --region eu-west-1 > /tmp/old-retriever-config.json

# Save web experience details
aws qbusiness get-web-experience \
  --application-id 33b247da-92e9-42f4-a03e-892b28b51c21 \
  --web-experience-id d5bffe17-4d13-45fb-9a9d-d8b662851ade \
  --region eu-west-1 > /tmp/old-web-config.json
```

#### 2. Create Identity Center Application

```bash
# Get Identity Center instance
INSTANCE_ARN=$(aws sso-admin list-instances --region eu-west-1 --query 'Instances[0].InstanceArn' --output text)

# Create Q Business application in Identity Center
aws sso-admin create-application \
  --application-provider-arn arn:aws:sso::aws:applicationProvider/custom \
  --instance-arn $INSTANCE_ARN \
  --name "VaultMesh Q Business" \
  --description "RUBEDO Actions - SSO Enabled" \
  --status ENABLED \
  --region eu-west-1

# Save the ApplicationArn
IDC_APP_ARN="arn:aws:sso::509399262563:application/..." # from output
```

#### 3. Create New Q Business Application with SSO

```bash
cd 02-qbusiness/app

# Create new app with SSO
aws qbusiness create-application \
  --display-name "VaultMesh-Knowledge-Assistant-SSO" \
  --description "Enterprise AI for VaultMesh Technologies (SSO Enabled)" \
  --identity-type AWS_IAM_IDC \
  --iam-identity-provider-arn $IDC_APP_ARN \
  --region eu-west-1

# Save new application ID
NEW_APP_ID="..." # from output
```

#### 4. Create New Retriever (Link to Same Index)

```bash
aws qbusiness create-retriever \
  --application-id $NEW_APP_ID \
  --display-name "VaultMesh-Retriever-SSO" \
  --type NATIVE_INDEX \
  --configuration "{\"nativeIndexConfiguration\":{\"indexId\":\"07742e35-7209-40d9-bb9d-6e190c4558f7\"}}" \
  --region eu-west-1

# Save new retriever ID
NEW_RETRIEVER_ID="..." # from output
```

#### 5. Create New Web Experience

```bash
aws qbusiness create-web-experience \
  --application-id $NEW_APP_ID \
  --title "VaultMesh Knowledge Assistant" \
  --subtitle "Enterprise AI powered by RUBEDO" \
  --region eu-west-1

# Save new web experience ID and URL
NEW_WEB_ID="..." # from output
NEW_WEB_URL="..." # from output
```

#### 6. Update Environment Variables

```bash
# Update .env.local with new IDs
cat >> .env.local << EOF
# SSO Migration - New IDs
QBUSINESS_APP_ID=$NEW_APP_ID
QBUSINESS_RETRIEVER_ID=$NEW_RETRIEVER_ID
QBUSINESS_WEB_EXPERIENCE_ID=$NEW_WEB_ID
QBUSINESS_WEB_URL=$NEW_WEB_URL
EOF
```

---

## Post-Migration Configuration

### 1. Apply Full Guardrails

With SSO enabled, you can now apply full topic controls:

```bash
aws qbusiness update-chat-controls-configuration \
  --application-id $NEW_APP_ID \
  --region eu-west-1 \
  --cli-input-json file://02-qbusiness/guardrails/vaultmesh-guardrails.json
```

**Verify:**
```bash
aws qbusiness get-chat-controls-configuration \
  --application-id $NEW_APP_ID \
  --region eu-west-1
```

Expected:
```json
{
  "responseScope": "ENTERPRISE_CONTENT_ONLY",
  "blockedPhrases": [...],
  "topicConfigurations": [
    {
      "name": "credentials-and-secrets",
      "rules": [...],
      "userGroups": ["VaultMesh-Engineering", "VaultMesh-Delivery"]
    }
  ]
}
```

### 2. Update UI Integration

**Remove anonymous fallback:**

Edit `.env.local`:
```bash
# DELETE these lines:
# DEFAULT_GROUP=VaultMesh-Engineering
# DEFAULT_USER_ID=anon@vaultmesh.io
```

**Update API routes to require SSO:**

Edit `src/app/api/actions/invoke/route.ts`:
```typescript
export async function POST(req: NextRequest) {
  // Get user from session (SSO)
  const session = await getServerSession(authOptions);

  if (!session?.user) {
    return NextResponse.json(
      { error: "Authentication required" },
      { status: 401 }
    );
  }

  const { actionId, params } = await req.json();

  // User groups from Identity Center
  const user = {
    id: session.user.email,
    groups: session.user.groups, // From IDC
  };

  // Rest of invoke logic...
}
```

### 3. Configure Group Assignments

Assign users to groups in Identity Center:

```bash
# Get identity store ID
IDENTITY_STORE_ID=$(aws sso-admin list-instances --region eu-west-1 --query 'Instances[0].IdentityStoreId' --output text)

# Get group IDs
aws identitystore list-groups \
  --identity-store-id $IDENTITY_STORE_ID \
  --region eu-west-1

# Assign user to group
aws identitystore create-group-membership \
  --identity-store-id $IDENTITY_STORE_ID \
  --group-id <group-id> \
  --member-id UserId=<user-id> \
  --region eu-west-1
```

---

## Testing SSO Integration

### 1. Test Login Flow

```bash
# 1. Navigate to web experience URL
echo "Web URL: $NEW_WEB_URL"

# 2. Should redirect to Identity Center login
# 3. Login with test user
# 4. Should redirect back to Q Business
```

### 2. Test Group-Based Authorization

**Engineering User:**
```bash
# Should be able to invoke summarize-docs
./04-ui-integration/scripts/action-invoke.sh summarize-docs \
  alice@vaultmesh.io VaultMesh-Engineering \
  '{"documentUris":["s3://vaultmesh-knowledge-base/polis-overview.md"]}'

# Expected: HTTP 200
```

**Unknown User:**
```bash
# Should be denied
./04-ui-integration/scripts/action-invoke.sh summarize-docs \
  eve@example.com Unknown-Group \
  '{"documentUris":["s3://test/doc.md"]}'

# Expected: HTTP 403
```

### 3. Verify Persona Resolution

Check logs to confirm persona mapping:
```bash
aws logs tail /aws/lambda/vmq-summarize-docs \
  --region eu-west-1 \
  --since 10m \
  --format short \
  | grep persona

# Expected: "persona":"engineer" for Engineering group
```

### 4. Test Topic Controls

Try asking Q Business a question about credentials:
```
User: "What is the AWS access key?"
Expected: Blocked by guardrails topic control
```

---

## Rollback Procedure

If SSO migration fails, rollback to Anonymous mode:

### Option A: Revert Application (if you updated existing)

```bash
# Disable SSO (may not work - AWS limitation)
aws qbusiness update-application \
  --application-id 33b247da-92e9-42f4-a03e-892b28b51c21 \
  --identity-type ANONYMOUS \
  --region eu-west-1
```

### Option B: Switch Back to Old App (if you created new)

```bash
# Restore old app ID in .env.local
cat >> .env.local << EOF
# Rollback to Anonymous
QBUSINESS_APP_ID=33b247da-92e9-42f4-a03e-892b28b51c21
QBUSINESS_RETRIEVER_ID=07742e35-7209-40d9-bb9d-6e190c4558f7
QBUSINESS_WEB_EXPERIENCE_ID=d5bffe17-4d13-45fb-9a9d-d8b662851ade
DEFAULT_GROUP=VaultMesh-Engineering
DEFAULT_USER_ID=anon@vaultmesh.io
EOF

# Redeploy with anonymous config
npm run build && npm run deploy
```

---

## Migration Checklist

### Pre-Migration
- [ ] IAM Identity Center enabled in eu-west-1
- [ ] User groups created in Identity Center
- [ ] Test users assigned to groups
- [ ] Identity Center application created
- [ ] Backup current app configuration

### Migration
- [ ] New Q Business app created with SSO (or existing updated)
- [ ] New retriever linked to existing index
- [ ] New web experience created
- [ ] Full guardrails applied

### Post-Migration
- [ ] UI updated to use SSO session
- [ ] Anonymous fallback removed from .env.local
- [ ] Test login flow works
- [ ] Test group-based authorization
- [ ] Test persona resolution
- [ ] Test topic controls
- [ ] Update documentation with new app ID/URL

### Validation
- [ ] Engineering user can invoke actions
- [ ] Unknown user gets 403
- [ ] Persona resolves correctly per group
- [ ] Topic controls block credentials questions
- [ ] CloudWatch logs show correct user attribution

---

## Estimated Timeline

**Total: 2-3 hours**

1. Identity Center setup (if needed): 30 min
2. Create/configure application: 45 min
3. Update UI integration: 30 min
4. Testing & validation: 45 min
5. Documentation updates: 15 min

---

## Success Criteria

✅ **SSO login working**
✅ **Group-based authorization enforced**
✅ **Persona auto-resolution from groups**
✅ **Full topic controls active**
✅ **Response scope filtering enabled**
✅ **CloudWatch logs show real user IDs**

---

## Support

**Identity Center Issues:**
- AWS Support: https://console.aws.amazon.com/support/
- IAM Identity Center Docs: https://docs.aws.amazon.com/singlesignon/

**Q Business Issues:**
- Q Business Docs: https://docs.aws.amazon.com/amazonq/
- #vaultmesh-ops (Slack)

---

## Current App Status

```json
{
  "ApplicationId": "33b247da-92e9-42f4-a03e-892b28b51c21",
  "Status": "ACTIVE",
  "Name": "VaultMesh-Knowledge-Assistant",
  "IdentityType": "ANONYMOUS",
  "Description": "Enterprise AI for VaultMesh Technologies"
}
```

**Next Step:** Choose Option A (update) or Option B (create new) and begin migration.

---

**Once SSO is enabled, RUBEDO reaches full operational capability.** 🔐
