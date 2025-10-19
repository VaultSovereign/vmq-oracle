# RUBEDO UI Integration - Go-Live Checklist

**Version:** 1.0.0-rubedo
**Date:** 2025-10-19
**Target:** 48-hour go-live

---

## Pre-Flight Checks

### Infrastructure (Already Complete ✓)
- [x] 6 Lambda functions deployed (`vmq-actions-rubedo` stack)
- [x] Actions catalog published to S3 with resolved ARNs
- [x] 3 personas published to S3 (engineer, delivery-manager, compliance)
- [x] Anonymous-mode guardrails applied (blocked phrases)
- [x] CloudWatch metrics and dashboard configured
- [x] Validation script passing all checks

### UI Integration Package (Ready ✓)
- [x] Server-side AWS SDK helpers (`lib/aws.ts`, `lib/persona.ts`)
- [x] API routes for catalog and invocation
- [x] React component for action handoff buttons
- [x] Environment configuration template
- [x] CLI test harness for manual testing
- [x] Complete documentation

---

## Day 1: UI Wiring (Today)

### 1. Install Dependencies
```bash
npm install @aws-sdk/client-s3 @aws-sdk/client-lambda
# or
yarn add @aws-sdk/client-s3 @aws-sdk/client-lambda
```
**Time:** 2 minutes
**Owner:** Frontend team

---

### 2. Copy Integration Files
```bash
# Server utilities
cp 04-ui-integration/lib/aws.ts src/lib/aws.ts
cp 04-ui-integration/lib/persona.ts src/lib/persona.ts

# API routes (Next.js App Router)
mkdir -p src/app/api/actions/{catalog,invoke}
cp 04-ui-integration/api/catalog-route.ts src/app/api/actions/catalog/route.ts
cp 04-ui-integration/api/invoke-route.ts src/app/api/actions/invoke/route.ts

# Components
cp 04-ui-integration/components/ActionHandoff.tsx src/components/ActionHandoff.tsx
```
**Time:** 5 minutes
**Owner:** Frontend team

---

### 3. Configure Environment
```bash
cp 04-ui-integration/config/env.template .env.local
# Edit .env.local with your values
```

Ensure server has IAM role with:
- `s3:GetObject` on `vaultmesh-knowledge-base/{actions,personas}/*`
- `lambda:InvokeFunction` on `vmq-*` functions

**Time:** 10 minutes
**Owner:** DevOps + Frontend

---

### 4. Add Component to Chat UI
```tsx
import ActionHandoff from "@/components/ActionHandoff";

export default function ChatPage() {
  const [selectedDocs, setSelectedDocs] = useState<string[]>([]);

  return (
    <div>
      {/* Your existing chat interface */}

      {/* Add action buttons */}
      <ActionHandoff
        selectedUris={selectedDocs}
        user={{ id: "anon@vaultmesh.io", groups: ["VaultMesh-Engineering"] }}
      />
    </div>
  );
}
```
**Time:** 15 minutes
**Owner:** Frontend team

---

### 5. Test Locally
```bash
# Start dev server
npm run dev

# In another terminal, test catalog
curl http://localhost:3000/api/actions/catalog | jq .

# Test invocation (authorized)
./04-ui-integration/scripts/action-invoke.sh summarize-docs \
  alice@vaultmesh.io VaultMesh-Engineering \
  '{"documentUris":["s3://vaultmesh-knowledge-base/polis-overview.md"]}'

# Test invocation (unauthorized - expect 403)
./04-ui-integration/scripts/action-invoke.sh summarize-docs \
  eve@example.com Unknown-Group \
  '{"documentUris":["s3://test/doc.md"]}'
```
**Time:** 15 minutes
**Owner:** Frontend + QA

**Expected Results:**
- Catalog returns 6 actions
- Authorized call returns 200 with stub result
- Unauthorized call returns 403 with deny reason

---

### 6. Deploy to Staging
```bash
# Build and deploy
npm run build
# Deploy to your staging environment
```

Verify:
- Actions buttons render in staging UI
- Click "Summarize these docs" → stub result appears
- Check CloudWatch logs for `action_ok` events
- Check CloudWatch metrics dashboard for `ActionsInvoked` tick

**Time:** 20 minutes
**Owner:** DevOps

---

### 7. Persona Injection at Session Init

Update your chat initialization code:

```typescript
import { resolvePersona, personaToSystemContext } from "@/lib/persona";

async function initChatSession(user: { groups: string[] }) {
  // 1. Resolve persona
  const persona = await resolvePersona(user.groups);
  const systemContext = personaToSystemContext(persona);

  // 2. Inject into Q Business session
  const session = await qbusiness.createChatSession({
    userId: user.id,
    systemPrompt: buildSystemPrompt(systemContext),
  });

  return session;
}

function buildSystemPrompt(ctx: SystemContext) {
  return `
You are a helpful AI assistant for VaultMesh.

Tone: ${ctx.tone}
Preferred Sources: ${ctx.preferred_sources.join(", ")}

${ctx.answer_guidance.join("\n")}
  `.trim();
}
```

**Time:** 20 minutes
**Owner:** Backend team

---

## Day 2: SSO Enablement (Tomorrow)

### 1. Create Identity Center Application
```bash
# Via AWS Console or CLI
aws sso-admin create-application \
  --application-provider-arn arn:aws:sso::aws:applicationProvider/custom \
  --name "VaultMesh Q Business" \
  --region eu-west-1

# Note the application ARN
```
**Time:** 15 minutes
**Owner:** Security + DevOps

---

### 2. Update Q Business Application to SSO

**Option A: Update Existing (if supported)**
```bash
aws qbusiness update-application \
  --application-id 33b247da-92e9-42f4-a03e-892b28b51c21 \
  --identity-type AWS_IAM_IDC \
  --iam-identity-provider-arn <identity-center-app-arn> \
  --region eu-west-1
```

**Option B: Create New Application**
```bash
cd 02-qbusiness/app
# Edit create-application.sh:
# - Set identityType=AWS_IAM_IDC
# - Set iamIdentityProviderArn=<your-sso-arn>
./create-application.sh

# Note new application ID
# Update retriever, web experience with new app ID
```

**Time:** 30 minutes
**Owner:** DevOps + Security

---

### 3. Apply Full Guardrails

Once SSO is active:
```bash
aws qbusiness update-chat-controls-configuration \
  --application-id <new-app-id> \
  --region eu-west-1 \
  --cli-input-json file://02-qbusiness/guardrails/vaultmesh-guardrails.json
```

This enables:
- Topic controls (credentials, confidential-business-info)
- `responseScope: ENTERPRISE_CONTENT_ONLY`
- Group-scoped filtering

**Time:** 10 minutes
**Owner:** DevOps

---

### 4. Update UI to Use Real Identity

Remove fallback from `.env.local`:
```bash
# DELETE these lines:
# DEFAULT_GROUP=VaultMesh-Engineering
# DEFAULT_USER_ID=anon@vaultmesh.io
```

Update auth integration:
```typescript
// Before (Anonymous)
const user = { id: DEFAULT_USER_ID, groups: [DEFAULT_GROUP] };

// After (SSO)
const session = await getServerSession();
const user = {
  id: session.user.email,
  groups: session.user.groups, // From Identity Center
};
```

**Time:** 30 minutes
**Owner:** Frontend + Auth team

---

### 5. Test SSO Flow

```bash
# 1. Login as Engineering user
# 2. Click "Summarize these docs" → expect 200
# 3. Check logs for correct group

# 4. Login as unknown user
# 5. Click any action → expect 403
# 6. Check logs for deny_reason
```

**Time:** 20 minutes
**Owner:** QA

---

### 6. Deploy to Production

```bash
# Final build
npm run build

# Deploy
# Update environment variables
# Restart services
```

Verify:
- All 6 action buttons visible
- SSO login works
- Actions invoke successfully
- CloudWatch metrics updating
- Dashboard shows ActionsInvoked > 0

**Time:** 30 minutes
**Owner:** DevOps

---

## Day 3: Observability & Monitoring

### 1. Set Up Alarms

Create CloudWatch alarms for:
- Lambda errors > 0
- 403 rate > 5%
- Action latency p95 > 10s

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name rubedo-action-errors \
  --alarm-description "Alert on Lambda errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=vmq-summarize-docs
```

**Time:** 30 minutes
**Owner:** DevOps

---

### 2. Create Logs Insights Saved Queries

**Actions Per Day:**
```
fields @timestamp, action, user.group
| filter event = "action_ok"
| stats count() by action
| sort count desc
```

**Authorization Denials:**
```
fields @timestamp, action, user.group, reason
| filter event = "action_err" and status = 403
| sort @timestamp desc
```

Save these to CloudWatch Logs Insights.

**Time:** 15 minutes
**Owner:** DevOps

---

### 3. Weekly Review Schedule

Set up recurring reviews:
- **Daily (first week):** Check dashboard, verify metrics growing
- **Weekly:** Review logs for patterns, adjust policies if needed
- **Monthly:** Assess action usage, plan YELLOW tier rollout

**Time:** Setup 10 minutes, ongoing
**Owner:** Product + Engineering

---

## Success Criteria

### Functionality
- [ ] All 6 actions render and invoke successfully
- [ ] Authorized users get 200 responses
- [ ] Unauthorized users get 403 with clear deny reason
- [ ] Personas load and shape chat tone correctly
- [ ] Results display properly in UI

### Performance
- [ ] Action latency p95 < 500ms (stubs)
- [ ] Catalog load < 100ms
- [ ] No Lambda cold start issues

### Observability
- [ ] CloudWatch metrics showing ActionsInvoked > 0
- [ ] Structured logs capture all invocations
- [ ] Dashboard widgets updating every 5 minutes
- [ ] Alarms configured and tested

### Security
- [ ] SSO enabled (post-Day 2)
- [ ] Full guardrails active
- [ ] No AWS credentials in browser
- [ ] IAM roles scoped correctly

---

## Rollback Plan

### Emergency Disable (< 1 minute)
```bash
# Disable all actions in catalog
aws s3 cp s3://vaultmesh-knowledge-base/actions/catalog.json /tmp/
jq '.catalog[].enabled = false' /tmp/catalog.json > /tmp/catalog-disabled.json
aws s3 cp /tmp/catalog-disabled.json s3://vaultmesh-knowledge-base/actions/catalog.json --cache-control "no-cache"
```

### Partial Rollback (< 5 minutes)
```bash
# Revert to previous catalog version
aws s3 cp s3://vaultmesh-knowledge-base/actions/catalog.json.backup \
  s3://vaultmesh-knowledge-base/actions/catalog.json --cache-control "no-cache"
```

### Full Stack Rollback (< 10 minutes)
```bash
# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name vmq-actions-rubedo --region eu-west-1

# Remove UI components (git revert)
git revert <commit-hash>
git push
```

---

## Post-Launch Monitoring (First Week)

### Daily Checks
- [ ] Dashboard review: Actions invoked, error rate, latency
- [ ] Logs review: Any unexpected denials or errors?
- [ ] User feedback: Any UI/UX issues?

### Week 1 Metrics to Track
- **Total actions invoked:** Target > 50
- **Error rate:** Target < 1%
- **403 rate:** Target < 5%
- **User satisfaction:** Survey or Slack feedback

### Iteration Plan
Based on Week 1 data:
1. Identify most-used actions → prioritize for LLM implementation
2. Identify denial patterns → adjust policies if needed
3. Gather UI feedback → refine component UX
4. Plan YELLOW tier actions for Week 2-4

---

## Support & Escalation

**Incidents:**
- Slack: #vaultmesh-ops
- PagerDuty: On-call rotation
- Runbook: `RUNBOOK-IR.md`

**Questions:**
- Documentation: `04-ui-integration/README.md`
- Integration Guide: `02-qbusiness/actions/RUBEDO-INTEGRATION.md`
- Rollout Guide: `02-qbusiness/actions/ROLLOUT-GUIDE.md`

---

## Sign-Off

**Pre-Launch:**
- [ ] Engineering Lead
- [ ] Security Lead
- [ ] Product Manager

**Post-Launch (Day 3):**
- [ ] DevOps verification complete
- [ ] Monitoring configured
- [ ] Documentation updated with production URLs/IDs

---

**Go/No-Go Decision:** [___________]
**Launch Date:** [___________]
**Launched By:** [___________]
