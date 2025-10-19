# VaultMesh Q Business - UI Integration Package

**Version:** 1.0.0-rubedo
**Status:** Production-Ready
**Last Updated:** 2025-10-19

---

## Overview

This package provides complete UI integration for the **RUBEDO Actions** system, enabling your web application to:

1. **Load the Actions Catalog** from S3
2. **Resolve and inject Personas** at chat initialization
3. **Render handoff buttons** from the catalog
4. **Invoke Lambda actions** with the standard payload contract
5. **Display results** with proper error handling

### Architecture Flow

```
User → Chat UI → ActionHandoff Component
                       ↓
                  POST /api/actions/invoke
                       ↓
            ┌──────────┴──────────┐
            │ 1. Resolve Persona  │
            │ 2. Load Catalog     │
            │ 3. Build Payload    │
            │ 4. Invoke Lambda    │
            └─────────┬───────────┘
                      ↓
            Lambda (vmq-{action-id})
                      ↓
            ┌─────────┴──────────┐
            │ OPA Policy Gate    │
            │ Execute Action     │
            │ Emit CW Metrics    │
            └─────────┬──────────┘
                      ↓
                 Result/Error
                      ↓
              UI Display Component
```

---

## Quick Start

### 1. Install Dependencies

```bash
npm install @aws-sdk/client-s3 @aws-sdk/client-lambda
```

Or with yarn:
```bash
yarn add @aws-sdk/client-s3 @aws-sdk/client-lambda
```

### 2. Configure Environment

Copy the environment template:
```bash
cp config/env.template .env.local
```

Edit `.env.local`:
```bash
AWS_REGION=eu-west-1
AWS_S3_BUCKET=vaultmesh-knowledge-base
AWS_ACCOUNT_ID=509399262563
INVOKER_MODE=direct

# Remove after SSO is enabled
DEFAULT_GROUP=VaultMesh-Engineering
DEFAULT_USER_ID=anon@vaultmesh.io
```

### 3. Copy Files to Your Project

**For Next.js App Router:**

```bash
# Server utilities
cp lib/aws.ts src/lib/aws.ts
cp lib/persona.ts src/lib/persona.ts

# API routes
cp api/catalog-route.ts src/app/api/actions/catalog/route.ts
cp api/invoke-route.ts src/app/api/actions/invoke/route.ts

# Components
cp components/ActionHandoff.tsx src/components/ActionHandoff.tsx
```

**For other frameworks:** Adapt the API routes to your framework's routing system (Express, Fastify, etc.). See comments in each file for examples.

### 4. Add to Your Chat UI

```tsx
import ActionHandoff from "@/components/ActionHandoff";

export default function ChatPage() {
  const [selectedDocs, setSelectedDocs] = useState<string[]>([]);
  const user = useUser(); // Your auth system

  return (
    <div>
      {/* Your chat interface */}

      {/* Action handoff buttons */}
      <ActionHandoff
        selectedUris={selectedDocs}
        user={user}
        onResult={(actionId, result) => {
          console.log(`Action ${actionId} completed:`, result);
        }}
        onError={(actionId, error) => {
          console.error(`Action ${actionId} failed:`, error);
        }}
      />
    </div>
  );
}
```

---

## File Structure

```
04-ui-integration/
├── lib/
│   ├── aws.ts              # S3 & Lambda SDK helpers (server-side)
│   └── persona.ts          # Persona resolution & loading
├── api/
│   ├── catalog-route.ts    # GET /api/actions/catalog
│   └── invoke-route.ts     # POST /api/actions/invoke
├── components/
│   └── ActionHandoff.tsx   # React component for action buttons
├── scripts/
│   └── action-invoke.sh    # CLI test harness
├── config/
│   ├── env.template        # Environment configuration
│   └── package.json        # Dependencies
└── README.md               # This file
```

---

## API Reference

### GET /api/actions/catalog

Returns the actions catalog from S3.

**Response:**
```json
{
  "version": "1.0.0-rubedo",
  "catalog": [
    {
      "id": "summarize-docs",
      "name": "Summarize documents",
      "description": "...",
      "lambda": "arn:aws:lambda:...:function:vmq-summarize-docs",
      "safetyTier": "GREEN",
      "invocation": {
        "mode": "chat.suggestedAction",
        "handoffText": "Summarize these docs"
      }
    }
  ]
}
```

### POST /api/actions/invoke

Invokes a RUBEDO action Lambda.

**Request:**
```json
{
  "actionId": "summarize-docs",
  "user": {
    "id": "alice@vaultmesh.io",
    "groups": ["VaultMesh-Engineering"]
  },
  "params": {
    "documentUris": ["s3://bucket/doc.md"],
    "audience": "engineering"
  }
}
```

**Response (Success):**
```json
{
  "statusCode": 200,
  "body": {
    "summaryMarkdown": "# Executive Summary\n..."
  }
}
```

**Response (Denied):**
```json
{
  "statusCode": 403,
  "body": {
    "error": "action summarize-docs is not enabled for group Unknown-Group"
  }
}
```

---

## Testing

### CLI Test Harness

Test actions from the command line:

```bash
./scripts/action-invoke.sh summarize-docs \
  alice@vaultmesh.io \
  VaultMesh-Engineering \
  '{"documentUris":["s3://vaultmesh-knowledge-base/polis-overview.md"]}'
```

Expected output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VaultMesh Q Business - Action Invocation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Action:  summarize-docs
User:    alice@vaultmesh.io
Group:   VaultMesh-Engineering

✓ Success (HTTP 200)

Response:
{
  "summaryMarkdown": "# Executive Summary (STUB)..."
}
```

### Test Authorization Deny

```bash
./scripts/action-invoke.sh validate-schema \
  eve@example.com \
  Unknown-Group \
  '{"schemaUri":"s3://test/schema.json"}'
```

Expected: HTTP 403 with deny reason.

---

## Persona System

The persona system shapes chat responses based on user role without fragmenting content.

### Persona Resolution Flow

1. User logs in via SSO → Identity Center provides groups
2. Server calls `resolvePersona(groups)` → maps to persona ID
3. Server loads persona JSON from S3 (cached 5 min)
4. Persona context injected into chat session

### Persona Mapping

| Groups | Persona ID | Tone |
|--------|------------|------|
| VaultMesh-Engineering | engineer | Concise, code-first |
| VaultMesh-Delivery, VaultMesh-Management | delivery-manager | Pragmatic, status-first |
| VaultMesh-Compliance | compliance | Policy-first, traceability |

### Injecting Persona Context

In your chat initialization:

```typescript
import { resolvePersona, personaToSystemContext } from "@/lib/persona";

// On session start
const persona = await resolvePersona(user.groups);
const systemContext = personaToSystemContext(persona);

// Inject into Q Business session
const chatSession = await initQBusinessSession({
  userId: user.id,
  systemPrompt: {
    tone: systemContext.tone,
    preferredSources: systemContext.preferred_sources,
    answerGuidance: systemContext.answer_guidance.join("\n"),
  },
});
```

---

## SSO Upgrade Path

**Current State:** Anonymous mode (no user identity)
**Target State:** AWS IAM Identity Center (SSO) with group-based access

### Steps to Enable SSO

#### 1. Create Identity Center Application

```bash
# Via AWS Console or CLI
aws sso-admin create-application \
  --application-provider-arn arn:aws:sso::...:provider/qbusiness \
  --name "VaultMesh Q Business" \
  --region eu-west-1
```

#### 2. Update Q Business Application

Re-create your Q Business application with SSO identity type:

```bash
aws qbusiness update-application \
  --application-id 33b247da-92e9-42f4-a03e-892b28b51c21 \
  --identity-type AWS_IAM_IDC \
  --iam-identity-provider-arn arn:aws:sso:::application/... \
  --region eu-west-1
```

Or create a new application:
```bash
cd 02-qbusiness/app
# Edit create-application.sh to set identityType=AWS_IAM_IDC
./create-application.sh
```

#### 3. Apply Full Guardrails

Once SSO is active, apply full topic controls:

```bash
aws qbusiness update-chat-controls-configuration \
  --application-id <new-app-id> \
  --region eu-west-1 \
  --cli-input-json file://02-qbusiness/guardrails/vaultmesh-guardrails.json
```

This enables:
- Topic controls (credentials, confidential-business-info)
- Response scope: `ENTERPRISE_CONTENT_ONLY`
- Group-scoped content filtering

#### 4. Update UI to Use Real User Identity

Remove fallback values from `.env.local`:
```bash
# DELETE these lines after SSO is enabled
# DEFAULT_GROUP=VaultMesh-Engineering
# DEFAULT_USER_ID=anon@vaultmesh.io
```

Update your auth integration:
```typescript
// Before (Anonymous)
const user = { id: DEFAULT_USER_ID, groups: [DEFAULT_GROUP] };

// After (SSO)
const user = await getSessionUser(); // From your SSO provider
const user = {
  id: session.email,
  groups: session.groups // From Identity Center
};
```

#### 5. Verify Group Mapping

Test that groups map correctly:
```bash
# Test as Engineering
./scripts/action-invoke.sh summarize-docs \
  alice@vaultmesh.io VaultMesh-Engineering \
  '{"documentUris":["s3://..."]}'

# Test as unknown group (should deny)
./scripts/action-invoke.sh summarize-docs \
  eve@example.com Unknown-Group \
  '{"documentUris":["s3://..."]}'
```

---

## Security Considerations

### Server-Side Only

**CRITICAL:** All AWS SDK calls must remain server-side. Never expose:
- AWS credentials
- S3 bucket names (in client code)
- Lambda ARNs
- IAM roles

The `lib/aws.ts` and `lib/persona.ts` files are **server-only modules** and must not be imported in client components.

### IAM Permissions

Your server's IAM role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": [
        "arn:aws:s3:::vaultmesh-knowledge-base/actions/*",
        "arn:aws:s3:::vaultmesh-knowledge-base/personas/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["lambda:InvokeFunction"],
      "Resource": [
        "arn:aws:lambda:eu-west-1:509399262563:function:vmq-*"
      ]
    }
  ]
}
```

### OPA Pre-Check (Optional)

To short-circuit denies before Lambda invocation, set `OPA_URL` in `.env.local`:

```bash
OPA_URL=http://opa-server:8181/v1/data/vaultmesh/actions
```

The invoke API will pre-check authorization before calling Lambda.

---

## Observability

### CloudWatch Metrics

Each successful action invocation emits:
- **Namespace:** `VaultMesh/QBusinessActions`
- **Metric:** `ActionsInvoked`
- **Dimension:** `ActionId`

View in dashboard:
https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=VaultMesh-Sovereign

### Structured Logs

All Lambda invocations log to CloudWatch Logs:

**Success:**
```json
{
  "event": "action_ok",
  "action": "summarize-docs",
  "request_id": "rq-123",
  "user": {"id": "alice@vaultmesh.io", "group": "VaultMesh-Engineering"}
}
```

**Denied:**
```json
{
  "event": "action_err",
  "status": 403,
  "reason": "action not enabled for group",
  "action": "summarize-docs"
}
```

Query with CloudWatch Logs Insights:
```
fields @timestamp, action, user.group, request_id
| filter event = "action_ok"
| sort @timestamp desc
| limit 100
```

---

## Troubleshooting

### Actions Not Loading

**Symptom:** `GET /api/actions/catalog` returns 500

**Fix:**
1. Check IAM role has `s3:GetObject` for `vaultmesh-knowledge-base/actions/*`
2. Verify catalog exists: `aws s3 ls s3://vaultmesh-knowledge-base/actions/catalog.json`
3. Check server logs for S3 errors

### 403 Forbidden

**Symptom:** Action invocation returns 403

**Cause:** User's group not in action's GREEN allowlist

**Fix:**
1. Check CloudWatch logs for `deny_reason`
2. Verify user's groups: Should match one of:
   - VaultMesh-Engineering
   - VaultMesh-Delivery
   - VaultMesh-Compliance
   - VaultMesh-Management
3. Update GREEN map in `03-lambdas/common/vmq_common.py` if needed

### Lambda Timeout

**Symptom:** Action takes >10s and times out

**Fix:**
1. Increase timeout in `03-lambdas/template-sam.yaml`:
   ```yaml
   Globals:
     Function:
       Timeout: 30  # Increase to 30s
   ```
2. Redeploy: `cd 03-lambdas && ./deploy.sh`

### Persona Not Loading

**Symptom:** Persona resolution fails or defaults to engineer

**Fix:**
1. Check persona files exist in S3:
   ```bash
   aws s3 ls s3://vaultmesh-knowledge-base/personas/
   ```
2. Verify group mapping in `lib/persona.ts`
3. Check IAM role has read access to `personas/*`

---

## Roadmap

### Immediate (This Sprint)
- [x] UI integration package
- [x] Action handoff component
- [x] CLI test harness
- [ ] SSO enablement
- [ ] Full guardrails application

### Near-term (Fusion Tier)
- [ ] Replace Lambda stubs with LLM implementations
- [ ] Add approval workflow for YELLOW actions
- [ ] Deploy OPA server for centralized policy
- [ ] Memory layer (conversation context persistence)

### Medium-term (Sovereign Tier)
- [ ] Metering & quotas per persona/group
- [ ] Custom skills beyond GREEN catalog
- [ ] Cross-account federation
- [ ] Graph-aware action enrichment

---

## Support

**Documentation:**
- [RUBEDO Integration Guide](../02-qbusiness/actions/RUBEDO-INTEGRATION.md)
- [Rollout Guide](../02-qbusiness/actions/ROLLOUT-GUIDE.md)
- [Deployment Summary](../RUBEDO-DEPLOYMENT-SUMMARY.md)

**Ops:**
- Incident Runbook: `RUNBOOK-IR.md`
- DR Runbook: `RUNBOOK-DR.md`

**Contact:**
- Engineering: #vaultmesh-ops
- Escalation: PagerDuty on-call

---

**Version:** 1.0.0-rubedo
**Maintained by:** VaultMesh Engineering
**License:** Proprietary
