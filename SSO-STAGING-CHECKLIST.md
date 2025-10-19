# SSO Staging Checklist — RUBEDO Go-Live

**Purpose:** One-click verification and user onboarding checklist for SSO-enabled Q Business with RUBEDO Actions
**Target:** Production rollout after successful staging validation
**Owner:** VaultMesh Engineering + Operations

---

## Pre-Go-Live Validation ✓

### Infrastructure Health
- [x] Q Business app: `28332c1b-d6b7-49a7-bc53-fcb4e98606ee` ACTIVE
- [x] Index: `2da877f4-e6d2-4365-b3f9-65beeecd8f23` ACTIVE
- [x] Data Source sync: 11 documents indexed
- [x] Web Experience: https://z2jrdngc.chat.qbusiness.eu-west-1.on.aws/ ACTIVE
- [x] 6 Lambda functions deployed and updated with groups array support
- [x] Guardrails: ENTERPRISE_CONTENT_ONLY + 6 blocked phrases
- [x] CloudWatch dashboard: VaultMesh-Sovereign configured

### Authorization & Security
- [x] IAM Identity Center: 4 groups created (Engineering, Delivery, Management, Compliance)
- [x] Guardian user assigned to VaultMesh-Engineering
- [x] GREEN allowlist enforced in vmq_common.py
- [x] Smoke tests: 200 OK for authorized, 403 Forbidden for denied
- [x] OPA policy gate configured (fallback to static GREEN map)

### Observability
- [x] 6 Logs Insights queries created in `02-qbusiness/observability/logs-insights-queries.json`
- [x] Structured JSON logging active in all Lambdas
- [x] Metrics namespace: VaultMesh/QBusinessActions
- [x] Dashboard widgets: ActionsInvoked, ActionLatency

---

## SSO Staging Tasks (Day 1)

### User Onboarding
- [ ] **Add 5 pilot users** to IAM Identity Center
  ```bash
  # For each user:
  aws identitystore create-user \
    --identity-store-id d-90678e1e80 \
    --user-name <email> \
    --emails Value=<email>,Primary=true \
    --display-name "<Full Name>" \
    --region eu-west-1

  # Capture user-id from output
  ```

- [ ] **Assign users to groups** (Engineering: 2, Delivery: 2, Compliance: 1)
  ```bash
  # Get group IDs
  aws identitystore list-groups \
    --identity-store-id d-90678e1e80 \
    --region eu-west-1 \
    --output table

  # For each user:
  aws identitystore create-group-membership \
    --identity-store-id d-90678e1e80 \
    --group-id <group-id> \
    --member-id UserId=<user-id> \
    --region eu-west-1
  ```

- [ ] **Send pilot users SSO login instructions**
  - URL: https://z2jrdngc.chat.qbusiness.eu-west-1.on.aws/
  - Expected: Redirect to IAM Identity Center login
  - Credentials: Use their VaultMesh email + password (set via Identity Center)

### Smoke Testing with Real Users
- [ ] **Test Engineering persona** (guardian@vaultmesh.io or pilot user)
  - [ ] Login to web experience
  - [ ] Query: "What is the POLIS architecture?"
  - [ ] Expected: Answer referencing polis-overview.md
  - [ ] Invoke action: "Summarize these docs" (select 2-3 docs)
  - [ ] Expected: Stub summary returned, no errors

- [ ] **Test Delivery persona** (pilot user in VaultMesh-Delivery)
  - [ ] Login to web experience
  - [ ] Invoke action: "Draft FAQ" for a folder
  - [ ] Expected: 200 OK with stub FAQ
  - [ ] Try action: "Validate schema" (should be denied)
  - [ ] Expected: 403 Forbidden with deny reason

- [ ] **Test Compliance persona** (pilot user in VaultMesh-Compliance)
  - [ ] Login to web experience
  - [ ] Invoke action: "Assemble compliance pack"
  - [ ] Expected: 200 OK with stub package
  - [ ] Verify guardrails: Query "what is the password"
  - [ ] Expected: Blocked phrase response

### Dashboard & Metrics Verification
- [ ] **Open VaultMesh-Sovereign dashboard**
  - [ ] Confirm ActionsInvoked > 0 for summarize-docs, generate-faq, compliance-pack
  - [ ] Check ActionLatency p95 < 500ms (stubs should be fast)
  - [ ] Verify no errors in Lambda metrics

- [ ] **Run Logs Insights queries** (from `logs-insights-queries.json`)
  - [ ] "RUBEDO Actions per Day by Group" — shows Engineering, Delivery, Compliance
  - [ ] "RUBEDO Authorization Denials" — shows the validate-schema denial from Delivery user
  - [ ] "RUBEDO Top Users by Invocations" — shows pilot users
  - [ ] "RUBEDO Errors and Failures" — should be empty

### Catalog & Feature Flags
- [ ] **Publish Go-Live catalog** with `enabled: true` flags
  ```bash
  export AWS_REGION=eu-west-1
  export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

  envsubst < 02-qbusiness/actions/actions-catalog-golive.json > /tmp/catalog-golive.json

  aws s3 cp /tmp/catalog-golive.json \
    s3://vaultmesh-knowledge-base/actions/catalog.json \
    --region eu-west-1
  ```

- [ ] **Verify catalog in UI** (if integrated)
  - [ ] API route `/api/actions/catalog` returns 6 actions
  - [ ] All actions show `"enabled": true`

---

## SSO Staging Tasks (Day 2-3)

### UI Integration Testing
- [ ] **Frontend team deploys to staging** (see `04-ui-integration/INTEGRATION-CHECKLIST.md`)
  - [ ] ActionHandoff component integrated
  - [ ] .env.local configured with SSO app ID
  - [ ] Local smoke test passed
  - [ ] Staging deployment successful

- [ ] **End-to-end flow** with real SSO user
  - [ ] User logs into web experience
  - [ ] Selects documents in chat
  - [ ] Clicks action button (Summarize, FAQ, etc.)
  - [ ] Result rendered in UI
  - [ ] Metrics published to CloudWatch

### Performance & Load Testing
- [ ] **Simulate 50 actions** across 5 pilot users
  ```bash
  # Use 04-ui-integration/scripts/action-invoke.sh or curl
  # Target: All 6 actions invoked at least 5 times each
  ```

- [ ] **Check dashboard** after load test
  - [ ] ActionsInvoked total ≥ 50
  - [ ] ActionLatency p95 still < 500ms (stubs)
  - [ ] No Lambda throttles or errors
  - [ ] No authorization denials from valid users

### Saved Queries Setup
- [ ] **Create 6 Logs Insights saved queries** (from `logs-insights-queries.json`)
  - [ ] RUBEDO Actions per Day by Group
  - [ ] RUBEDO Authorization Denials
  - [ ] RUBEDO Action Latency p95 by Action
  - [ ] RUBEDO Errors and Failures
  - [ ] RUBEDO Top Users by Invocations
  - [ ] RUBEDO Persona Distribution

- [ ] **Bookmark queries** for daily ops review

### CloudWatch Alarms
- [ ] **Create alarm: Lambda Errors**
  ```bash
  aws cloudwatch put-metric-alarm \
    --alarm-name rubedo-lambda-errors \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --statistic Sum \
    --period 300 \
    --evaluation-periods 1 \
    --threshold 1 \
    --comparison-operator GreaterThanThreshold \
    --alarm-actions <SNS-TOPIC-ARN> \
    --dimensions Name=FunctionName,Value=vmq-summarize-docs \
    --region eu-west-1

  # Repeat for all 6 functions
  ```

- [ ] **Create alarm: High Latency**
  ```bash
  aws cloudwatch put-metric-alarm \
    --alarm-name rubedo-high-latency \
    --metric-name ActionLatency \
    --namespace VaultMesh/QBusinessActions \
    --statistic Average \
    --period 300 \
    --evaluation-periods 2 \
    --threshold 1000 \
    --comparison-operator GreaterThanThreshold \
    --alarm-actions <SNS-TOPIC-ARN> \
    --region eu-west-1
  ```

- [ ] **Create alarm: Authorization Denials Spike**
  - Use Logs Insights metric filter for `event = "action_deny"`
  - Threshold: > 10 denials in 5 minutes (may indicate attack or misconfiguration)

---

## Go-Live Readiness (Day 4+)

### Final Validation
- [ ] All SSO pilot users tested successfully (≥5 users, ≥3 personas)
- [ ] All 6 actions invoked at least once per persona
- [ ] Dashboard shows clean metrics (no errors, latency normal)
- [ ] Logs Insights queries all working
- [ ] CloudWatch alarms configured and tested
- [ ] Guardrails tested (blocked phrases, scope enforcement)
- [ ] UI integration deployed to staging and validated

### Rollback Plan Confirmed
- [ ] Old anonymous app still available: `33b247da-92e9-42f4-a03e-892b28b51c21`
- [ ] Rollback procedure documented in SSO-MIGRATION-COMPLETE.md
- [ ] Can revert catalog to non-SSO version if needed
- [ ] UI can switch back to ANONYMOUS mode via .env.local

### Production Deployment Decision
- [ ] **Stakeholder sign-off** from Engineering, Delivery, Compliance leads
- [ ] **Ops team ready** for production monitoring
- [ ] **Frontend team ready** to deploy production UI
- [ ] **Incident runbook** updated with RUBEDO-specific procedures
- [ ] **DR runbook** includes RUBEDO stack restore steps

### Production Rollout
- [ ] **Add remaining users** to Identity Center (all VaultMesh staff)
- [ ] **Assign groups** based on org chart
- [ ] **Update DNS/routing** if custom domain needed
- [ ] **Send company-wide announcement** with:
  - Web URL: https://z2jrdngc.chat.qbusiness.eu-west-1.on.aws/
  - Login instructions (SSO with VaultMesh email)
  - Available actions and personas
  - Feedback channels (#vaultmesh-ops Slack, support tickets)

- [ ] **Monitor for 48 hours**
  - [ ] Check dashboard every 4 hours
  - [ ] Review Logs Insights queries daily
  - [ ] Respond to alarms within SLA
  - [ ] Collect user feedback

---

## Post-Go-Live (Week 1)

### Success Metrics Review
- [ ] **Target metrics** (from SSO-OPERATIONAL.md):
  - [ ] SSO Logins: > 5 unique users ✓ (achieved: ___)
  - [ ] Actions Invoked: > 50 total ✓ (achieved: ___)
  - [ ] Error Rate: < 1% ✓ (achieved: ___%)
  - [ ] Authorization Deny Rate: < 5% ✓ (achieved: ___%)
  - [ ] User Satisfaction: Positive feedback ✓ (Net Promoter Score: ___)

### Iteration Planning
- [ ] **Analyze usage patterns** from Logs Insights
  - Which actions are most popular?
  - Which personas use which actions?
  - Are there deny patterns indicating missing group assignments?

- [ ] **User feedback synthesis**
  - What's working well?
  - What's confusing or broken?
  - What features are requested?

- [ ] **Plan Fusion tier rollout** (replace stubs with LLM implementations)
  - Priority actions based on usage data
  - Cost modeling for LLM API calls
  - Approval workflow for YELLOW-tier actions

---

## Quick Reference Commands

### Check sync status
```bash
aws qbusiness list-data-source-sync-jobs \
  --application-id 28332c1b-d6b7-49a7-bc53-fcb4e98606ee \
  --index-id 2da877f4-e6d2-4365-b3f9-65beeecd8f23 \
  --data-source-id c375f159-1813-4338-8277-7398ab3f10b3 \
  --region eu-west-1 --max-results 1 \
  --output json | jq '.history[0] | {Status: .status, Docs: .metrics.documentsAdded}'
```

### Test action invocation (CLI)
```bash
aws lambda invoke --function-name vmq-summarize-docs \
  --region eu-west-1 \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"summarize-docs","user":{"id":"test@vaultmesh.io","groups":["VaultMesh-Engineering"]},"params":{"documentUris":["s3://vaultmesh-knowledge-base/polis-overview.md"],"audience":"engineering"}}' \
  /tmp/test.json && cat /tmp/test.json | jq .
```

### List Identity Center users
```bash
aws identitystore list-users \
  --identity-store-id d-90678e1e80 \
  --region eu-west-1 \
  --output table
```

### List group memberships
```bash
# Get group ID first
aws identitystore list-groups \
  --identity-store-id d-90678e1e80 \
  --region eu-west-1 \
  --query 'Groups[?DisplayName==`VaultMesh-Engineering`].GroupId' \
  --output text

# List members
aws identitystore list-group-memberships \
  --identity-store-id d-90678e1e80 \
  --group-id <group-id> \
  --region eu-west-1 \
  --output table
```

### View latest Lambda logs
```bash
aws logs tail /aws/lambda/vmq-summarize-docs \
  --region eu-west-1 \
  --follow \
  --format short
```

### Run Logs Insights query
```bash
# Example: Actions per day
aws logs start-query \
  --log-group-names '/aws/lambda/vmq-summarize-docs' '/aws/lambda/vmq-generate-faq' \
  --start-time $(date -d '7 days ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, action, user.groups.0 as userGroup | filter event = "action_ok" | stats count() by bin(@timestamp, 1d), action, userGroup | sort @timestamp desc' \
  --region eu-west-1
```

---

## Contacts & Escalation

**Slack Channels:**
- #vaultmesh-ops — Ops team, incident response
- #vaultmesh-engineering — Engineering questions, feature requests
- #vaultmesh-users — End-user support, feedback

**PagerDuty:**
- On-call rotation: VaultMesh-Ops
- Escalation policy: RUBEDO Incidents

**Runbooks:**
- Incident Response: [RUNBOOK-IR.md](RUNBOOK-IR.md)
- Disaster Recovery: [RUNBOOK-DR.md](RUNBOOK-DR.md)
- SSO Migration: [SSO-MIGRATION-COMPLETE.md](SSO-MIGRATION-COMPLETE.md)

---

## Sign-Off

**Staging Complete:** ☐ Date: __________ By: __________
**Production Approved:** ☐ Date: __________ By: __________
**Go-Live Executed:** ☐ Date: __________ By: __________

---

**Generated:** 2025-10-19
**Owner:** VaultMesh Engineering
**Maintained in:** `vm-business-q/SSO-STAGING-CHECKLIST.md`
