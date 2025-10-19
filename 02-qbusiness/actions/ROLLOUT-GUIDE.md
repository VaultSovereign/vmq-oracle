# RUBEDO Actions - Rollout & Operations Guide

**Version:** 1.0.0-rubedo
**Date:** 2025-10-19
**Status:** PRODUCTION READY

---

## Overview

This guide covers the rollout, rollback, and operational procedures for the VaultMesh RUBEDO actions system.

**Architecture:**
- **6 GREEN-tier Lambda actions** (production-safe stubs)
- **OPA policy gate** with fallback to static allowlists
- **Persona-aware routing** (engineer, delivery-manager, compliance)
- **CloudWatch observability** (logs + metrics)
- **S3-based catalog** for dynamic action discovery

---

## Current Deployment

### Infrastructure
- **Stack:** `vmq-actions-rubedo` (CloudFormation)
- **Region:** `eu-west-1`
- **Account:** `509399262563`

### Lambda Functions
All functions deployed with:
- **Runtime:** Python 3.12
- **Memory:** 256 MB
- **Timeout:** 10s
- **Tracing:** X-Ray Active
- **Log Retention:** 14 days

| Function | ARN |
|----------|-----|
| vmq-summarize-docs | `arn:aws:lambda:eu-west-1:509399262563:function:vmq-summarize-docs` |
| vmq-generate-faq | `arn:aws:lambda:eu-west-1:509399262563:function:vmq-generate-faq` |
| vmq-draft-change-note | `arn:aws:lambda:eu-west-1:509399262563:function:vmq-draft-change-note` |
| vmq-validate-schema | `arn:aws:lambda:eu-west-1:509399262563:function:vmq-validate-schema` |
| vmq-create-jira-draft | `arn:aws:lambda:eu-west-1:509399262563:function:vmq-create-jira-draft` |
| vmq-generate-compliance-pack | `arn:aws:lambda:eu-west-1:509399262563:function:vmq-generate-compliance-pack` |

### Assets
- **Catalog:** `s3://vaultmesh-knowledge-base/actions/catalog.json` (v1.0.0-rubedo)
- **Personas:** `s3://vaultmesh-knowledge-base/personas/{engineer,delivery-manager,compliance}.json`
- **OPA Policy:** `02-qbusiness/guardrails/opa/actions.rego`

---

## Feature Flags & Control

### Per-Action Control
Each action in the catalog supports:
- **`enabled`** (boolean) - Master on/off switch
- **`safetyTier`** (GREEN/YELLOW/RED) - Deployment tier

**To disable an action:**
1. Edit `02-qbusiness/actions/actions-catalog.json`
2. Set `"enabled": false` for the target action
3. Publish to S3:
   ```bash
   export AWS_REGION=eu-west-1
   export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   envsubst < 02-qbusiness/actions/actions-catalog.json > /tmp/catalog.resolved.json
   aws s3 cp /tmp/catalog.resolved.json s3://vaultmesh-knowledge-base/actions/catalog.json \
     --region eu-west-1 --cache-control "no-cache"
   ```
4. Calls stop immediately (catalog is checked on each invocation)

### Policy Gate Control
Authorization is controlled by:
1. **OPA** (if `OPA_URL` is set) - Dynamic policy evaluation
2. **Static GREEN map** (fallback) - Hardcoded in `common/vmq_common.py`

**Current GREEN allowlist:**
```python
{
    "summarize-docs":    {"groups": {"VaultMesh-Engineering","VaultMesh-Delivery","VaultMesh-Compliance"}},
    "generate-faq":      {"groups": {"VaultMesh-Engineering","VaultMesh-Delivery"}},
    "draft-change-note": {"groups": {"VaultMesh-Engineering","VaultMesh-Delivery","VaultMesh-Management"}},
    "validate-schema":   {"groups": {"VaultMesh-Engineering"}},
    "create-jira-draft": {"groups": {"VaultMesh-Delivery","VaultMesh-Engineering"}},
    "compliance-pack":   {"groups": {"VaultMesh-Compliance","VaultMesh-Management"}},
}
```

---

## Rollout Procedures

### 1. Deploy New Actions
```bash
cd 03-lambdas
./deploy.sh
```
This will:
- Package all Lambda functions with common layer
- Upload to S3
- Deploy/update CloudFormation stack

### 2. Update Catalog
After adding/modifying actions in `actions-catalog.json`:
```bash
export AWS_REGION=eu-west-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
envsubst < 02-qbusiness/actions/actions-catalog.json > /tmp/catalog.resolved.json
aws s3 cp /tmp/catalog.resolved.json s3://vaultmesh-knowledge-base/actions/catalog.json \
  --region eu-west-1 --cache-control "no-cache"
```

### 3. Dark Launch (Feature Flag)
To test an action without exposing to users:
1. Deploy Lambda (step 1)
2. Keep `"enabled": false` in catalog
3. Test via direct Lambda invocation
4. When ready, set `"enabled": true` and publish catalog

### 4. Gradual Rollout
For YELLOW/RED tier actions:
1. Start with single group (e.g., `VaultMesh-Engineering`)
2. Monitor logs/metrics for 24-48h
3. Expand to additional groups
4. Update OPA policy or static map for each expansion

---

## Rollback Procedures

### Emergency Rollback (Disable Action)
**Time:** ~30 seconds
```bash
# Edit catalog to set "enabled": false
# Then publish:
export AWS_REGION=eu-west-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
envsubst < 02-qbusiness/actions/actions-catalog.json > /tmp/catalog.resolved.json
aws s3 cp /tmp/catalog.resolved.json s3://vaultmesh-knowledge-base/actions/catalog.json \
  --region eu-west-1 --cache-control "no-cache"
```
**Effect:** Calls stop immediately, Lambdas remain deployed

### Full Stack Rollback
**Time:** 2-3 minutes
```bash
aws cloudformation delete-stack --stack-name vmq-actions-rubedo --region eu-west-1
```
**Effect:** All Lambdas deleted, catalog remains but all invocations will fail

### Revoke Group Access
Update the GREEN map in `03-lambdas/common/vmq_common.py`:
```python
"action-id": {"groups": {"VaultMesh-Engineering"}},  # Remove other groups
```
Then redeploy:
```bash
cd 03-lambdas && ./deploy.sh
```

---

## Observability

### CloudWatch Logs
Each function logs structured JSON to `/aws/lambda/<function-name>`:

**Allowed invocation:**
```json
{"event":"action_ok","action":"summarize-docs","request_id":"test-1","user":{"id":"alice@vaultmesh.io","group":"VaultMesh-Engineering"}}
```

**Denied invocation:**
```json
{"event":"action_err","status":403,"reason":"action summarize-docs is not enabled for group Some-Other-Group","action":"summarize-docs","user":{"id":"eve@example.com","group":"Some-Other-Group"}}
```

### CloudWatch Metrics
**Namespace:** `VaultMesh/QBusinessActions`

**Metric:** `ActionsInvoked`
- **Dimensions:** `ActionId`
- **Unit:** Count
- **Period:** Published on every successful invocation

### Dashboard
**VaultMesh-Sovereign** dashboard includes:
- **Actions Invoked (24h)** - Single value widget showing total actions
- **Actions by Type (24h)** - Time series by action ID

**URL:** https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=VaultMesh-Sovereign

### Saved Queries (Logs Insights)
Create saved query for detailed action analytics:
```
fields @timestamp, action, user.group, context.persona, @message
| filter event = "action_ok"
| stats count() by action, user.group
| sort count desc
```

---

## Testing & Validation

### Smoke Test (Local)
```bash
cd 03-lambdas
python3 persona_helper.py invoke summarize-docs \
  '{"id":"alice@vaultmesh.io","group":"VaultMesh-Engineering"}' \
  '{"documentUris":["s3://vaultmesh-knowledge-base/polis-overview.md"],"audience":"delivery"}'
```

### Live Lambda Test
```bash
echo '{"action":"summarize-docs","user":{"id":"alice@vaultmesh.io","group":"VaultMesh-Engineering"},"context":{"request_id":"test-1","persona":"engineer"},"params":{"documentUris":["s3://vaultmesh-knowledge-base/polis-overview.md"],"audience":"delivery"}}' > /tmp/test-event.json

aws lambda invoke \
  --function-name vmq-summarize-docs \
  --cli-binary-format raw-in-base64-out \
  --payload file:///tmp/test-event.json \
  --region eu-west-1 \
  /tmp/out.json

cat /tmp/out.json | jq .
```

**Expected (authorized):**
```json
{
  "statusCode": 200,
  "body": "{\"summaryMarkdown\": \"# Executive Summary (STUB)...\"}"
}
```

**Expected (denied):**
```json
{
  "statusCode": 403,
  "body": "{\"error\": \"action summarize-docs is not enabled for group Some-Other-Group\"}"
}
```

### End-to-End Test Plan
1. **Policy gate:** Test authorized + unauthorized groups
2. **All actions:** Invoke each of the 6 actions with valid params
3. **Logs:** Verify `action_ok` and metric publication in CloudWatch
4. **Dashboard:** Confirm metrics appear on VaultMesh-Sovereign
5. **Catalog:** Verify handoff choices load from S3

---

## Migration to SSO (IAM Identity Center)

**Current:** Anonymous auth (no user context)
**Target:** AWS_IAM_IDC with group-based access

### Steps
1. **Create IAM Identity Center application** for Q Business
2. **Re-create Q Business app** with `identityType=AWS_IAM_IDC`
3. **Update guardrails** to include `responseScope=ENTERPRISE_CONTENT_ONLY`
4. **Map groups to personas** in `persona_helper.py` (already supports this)
5. **Test SSO login** and verify group mapping

**When SSO is live:**
- Remove Anonymous fallback from persona resolver
- Apply full guardrails (topics + blocked phrases + scope)
- Enable group-scoped content filtering

---

## Audit & Compliance

### Data Logged (Non-Sensitive)
- **request_id** - Unique invocation ID
- **action** - Action ID
- **user.id** - User email (hashed in production)
- **user.group** - Identity Center group
- **context.persona** - Assigned persona
- **allow/deny** - Authorization decision
- **params** (excluding PII)

### Retention
- **CloudWatch Logs:** 14 days
- **CloudWatch Metrics:** 15 months (standard)
- **X-Ray Traces:** 30 days

### Compliance Pack Generation
The `compliance-pack` action generates:
- ZIP bundle with referenced documents
- Markdown cover sheet with provenance
- OPA gate audit trail
- Guardrail configuration snapshot

---

## Troubleshooting

### Action not appearing in UI
1. Check catalog published to S3: `aws s3 cp s3://vaultmesh-knowledge-base/actions/catalog.json -`
2. Verify `enabled: true` for the action
3. Check Lambda ARN matches resolved catalog

### 403 Forbidden
1. Check user group matches GREEN allowlist
2. Review CloudWatch logs for `deny_reason`
3. Verify OPA_URL (if set) is reachable

### No metrics in dashboard
1. Confirm Lambda invocations succeeded (check logs for `action_ok`)
2. Verify IAM policy grants `cloudwatch:PutMetricData`
3. Check metric namespace: `VaultMesh/QBusinessActions`
4. Allow ~5 min delay for metrics to appear

### Lambda timeout
1. Current timeout: 10s (sufficient for stubs)
2. For production actions with LLM calls, increase to 30-60s
3. Update in `template-sam.yaml` or `deploy.sh` CloudFormation template

---

## Next Steps (Post-RUBEDO)

### Near-term (Fusion tier)
- Replace stub handlers with **LLM-powered implementations**
- Add **approval workflow** for YELLOW/RED actions
- Implement **memory layer** (conversation context persistence)
- Deploy **OPA server** for dynamic policy evaluation

### Medium-term (Sovereign tier)
- **SSO migration** to IAM Identity Center
- **Metering & quotas** per persona/group
- **Cross-account federation** for VaultMesh partners
- **Custom skills** beyond the GREEN catalog

### Long-term (Convergence)
- **Multi-modal actions** (PDF, images, audio)
- **Agentic workflows** (multi-step, conditional)
- **Policy marketplace** (shared OPA bundles)
- **Sovereign mesh** (federated knowledge graphs)

---

## Quick Reference Commands

```bash
# Deploy Lambdas
cd 03-lambdas && ./deploy.sh

# Publish catalog
export AWS_REGION=eu-west-1 AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
envsubst < 02-qbusiness/actions/actions-catalog.json > /tmp/catalog.resolved.json
aws s3 cp /tmp/catalog.resolved.json s3://vaultmesh-knowledge-base/actions/catalog.json --region eu-west-1 --cache-control "no-cache"

# Test action
aws lambda invoke --function-name vmq-summarize-docs --cli-binary-format raw-in-base64-out --payload file:///tmp/test-event.json --region eu-west-1 /tmp/out.json && cat /tmp/out.json

# View logs (last 10 min)
aws logs tail /aws/lambda/vmq-summarize-docs --region eu-west-1 --since 10m --format short

# Check metrics
aws cloudwatch get-metric-statistics \
  --namespace VaultMesh/QBusinessActions \
  --metric-name ActionsInvoked \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Sum \
  --region eu-west-1

# Disable action (emergency)
# Edit actions-catalog.json, set "enabled": false, then:
aws s3 cp /tmp/catalog.resolved.json s3://vaultmesh-knowledge-base/actions/catalog.json --region eu-west-1 --cache-control "no-cache"
```

---

**Maintainer:** VaultMesh Engineering
**Incident Contact:** #vaultmesh-ops
**Documentation:** [RUBEDO-INTEGRATION.md](./RUBEDO-INTEGRATION.md)
