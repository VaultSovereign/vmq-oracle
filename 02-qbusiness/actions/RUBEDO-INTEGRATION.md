# RUBEDO Actions System • End-to-End Integration Guide

**Version:** 1.0.0-rubedo
**Date:** 2025-10-19
**Status:** Production-Ready (GREEN tier actions)

---

## Overview

The **RUBEDO Actions** system provides guarded, role-aware action orchestration for VaultMesh Q Business. This document describes the complete integration flow from chat UI → persona resolution → catalog lookup → Lambda invocation → policy gating → metrics.

### Architecture

```
┌──────────────┐
│  Chat UI     │──① User query + group ──────────────────┐
│ (Anonymous)  │                                          │
└──────────────┘                                          ▼
                                              ┌────────────────────────┐
                                              │ Persona Resolution     │
                                              │ • Group → persona_id   │
                                              │ • Load S3 persona JSON │
                                              └───────────┬────────────┘
                                                          │
                                                          ▼
┌──────────────┐                              ┌────────────────────────┐
│ Actions      │◄──② Load catalog ─────────── │ Catalog (S3)           │
│ Catalog      │                              │ actions/catalog.json   │
│ (S3)         │                              └────────────────────────┘
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────┐
│ Lambda Invocation                                                │
│  • Function: vmq-{action-id}                                     │
│  • Payload: {action, user{id,group}, context{request_id,persona},│
│              params}                                             │
└───────────────────────────────┬──────────────────────────────────┘
                                │
                                ▼
                  ┌───────────────────────────┐
                  │ OPA Policy Gate           │
                  │ • Check user.group        │
                  │ • Return allow/deny       │
                  │ • Fallback: GREEN map     │
                  └─────────┬─────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │ allow=true                │ allow=false
              ▼                           ▼
    ┌──────────────────┐        ┌──────────────────┐
    │ Execute Action   │        │ Return 403       │
    │ • Emit CW metric │        │ • Log deny reason│
    │ • Return result  │        └──────────────────┘
    └──────────────────┘
              │
              ▼
    ┌──────────────────┐
    │ CloudWatch Logs  │
    │ • Structured JSON│
    │ • request_id     │
    │ • persona        │
    │ • latency_ms     │
    └──────────────────┘
              │
              ▼
    ┌──────────────────────────┐
    │ CloudWatch Metrics       │
    │ VaultMesh/QBusinessActions│
    │ • ActionsInvoked (Sum)   │
    │ • Dimension: ActionId    │
    └──────────────────────────┘
```

---

## Components

### 1. Personas (S3: `personas/`)

Three role-optimized personas for **tone**, **preferred sources**, and **answer guidance**:

| Persona ID         | Groups                      | Tone               |
|--------------------|-----------------------------|---------------------|
| `engineer`         | VaultMesh-Engineering       | Concise, code-first |
| `delivery-manager` | VaultMesh-Delivery, -Management | Pragmatic, status-first |
| `compliance`       | VaultMesh-Compliance        | Policy-first, traceability |

**Loading:** Use `scripts/persona-helper.sh resolve <group>` to map group → persona and fetch the JSON definition.

### 2. Actions Catalog (S3: `actions/catalog.json`)

Six **GREEN**-tier actions:

| Action ID             | Lambda                            | Authorized Groups                           |
|-----------------------|-----------------------------------|---------------------------------------------|
| `summarize-docs`      | `vmq-summarize-docs`              | Engineering, Delivery, Compliance            |
| `generate-faq`        | `vmq-generate-faq`                | Engineering, Delivery                        |
| `draft-change-note`   | `vmq-draft-change-note`           | Engineering, Delivery, Management            |
| `validate-schema`     | `vmq-validate-schema`             | Engineering                                  |
| `create-jira-draft`   | `vmq-create-jira-draft`           | Delivery, Engineering                        |
| `compliance-pack`     | `vmq-generate-compliance-pack`    | Compliance, Management                       |

**Catalog structure:**
```json
{
  "version": "1.0.0-rubedo",
  "catalog": [
    {
      "id": "summarize-docs",
      "name": "Summarize documents",
      "lambda": "arn:aws:lambda:eu-west-1:509399262563:function:vmq-summarize-docs",
      "policy": "vaultmesh.actions.summarize_docs",
      "safetyTier": "GREEN",
      "invocation": {
        "mode": "chat.suggestedAction",
        "handoffText": "Summarize these docs"
      }
    }
  ]
}
```

### 3. Lambda Functions (CloudFormation: `vmq-actions-rubedo`)

**Deployment:**
```bash
cd 03-lambdas
./deploy.sh
```

All functions:
- **Runtime:** Python 3.12
- **Timeout:** 10s
- **Memory:** 256 MB
- **Tracing:** X-Ray Active
- **Log retention:** 14 days
- **IAM:** Read-only S3 (personas/catalog), CloudWatch PutMetricData

**Common handler pattern (`vmq_common.py`):**
```python
from common.vmq_common import authorize_action, ok, err, require

def handler(event, _ctx):
    # 1. Policy gate
    allowed, approval, deny = authorize_action(event)
    if not allowed and not approval:
        return err(403, deny or "denied", event)

    # 2. Validate params
    params, missing = require(event, "documentUris")
    if missing:
        return err(400, f"missing required param(s): {', '.join(missing)}", event)

    # 3. Execute action (stub for now)
    result = {"summaryMarkdown": "..."}

    # 4. Return + emit metric
    return ok(result, event)
```

### 4. OPA Policy (Optional)

**Location:** `02-qbusiness/guardrails/opa/actions.rego`

If `OPA_URL` env var is set, Lambdas call OPA for policy decisions. Otherwise, they fall back to the static GREEN map in `vmq_common.py`.

**OPA request contract:**
```json
{
  "input": {
    "action": "summarize-docs",
    "user": {"id": "alice@vaultmesh.io", "group": "VaultMesh-Engineering"},
    "context": {...},
    "params": {...}
  }
}
```

**OPA response:**
```json
{
  "result": {
    "allow": true,
    "approval_required": false,
    "deny_reason": ""
  }
}
```

### 5. Observability

#### Structured Logs (CloudWatch Logs)
Every action logs:
```json
{
  "event": "action_ok",
  "action": "summarize-docs",
  "request_id": "r-1",
  "user": {"id": "alice@vaultmesh.io", "group": "VaultMesh-Engineering"}
}
```

**Log groups:** `/aws/lambda/vmq-{action-name}` (14 day retention)

#### Metrics (CloudWatch Metrics)
- **Namespace:** `VaultMesh/QBusinessActions`
- **Metric:** `ActionsInvoked`
- **Dimension:** `ActionId`
- **Unit:** Count

**Dashboard:** [VaultMesh-Sovereign](https://console.aws.amazon.com/cloudwatch/deeplink.js?region=eu-west-1#dashboards:name=VaultMesh-Sovereign)

New widget: **RUBEDO Actions Invoked (24h)** shows per-action invocation counts.

---

## Integration Flows

### Flow 1: Chat UI → Invoke Action (Pre-SSO)

**Anonymous app mode** (current state):

1. **User query:** "Summarize the Polis overview doc"
2. **UI infers action:** `summarize-docs`
3. **UI calls helper:**
   ```bash
   ./scripts/persona-helper.sh invoke \
     summarize-docs \
     alice@vaultmesh.io \
     VaultMesh-Engineering \
     '{"documentUris":["s3://vaultmesh-knowledge-base/polis-overview.md"]}'
   ```
4. **Helper:**
   - Resolves persona: `VaultMesh-Engineering` → `engineer`
   - Loads catalog, extracts Lambda ARN
   - Invokes `vmq-summarize-docs` with standard payload
5. **Lambda:**
   - Policy gate: `allow=true` (Engineering in GREEN map)
   - Returns stub summary
   - Emits CloudWatch metric: `ActionsInvoked{ActionId=summarize-docs}=1`
6. **UI displays result**

### Flow 2: Persona-Aware Context Injection

When initializing a Q session:

```python
# Pseudo-code (UI or middleware)
persona_id = resolve_persona(user_groups=["VaultMesh-Engineering"])
persona = load_persona_s3(persona_id)  # Cache 5 min

# Inject into Q system prompt
system_context = {
  "tone": persona["tone"],
  "preferred_sources": persona["preferred_sources"],
  "answer_guidance": persona["answer_guidance"],
}
```

This tailors Q's responses **without fragmenting content** by role.

### Flow 3: Policy Deny

1. User `eve@example.com` with group `Some-Other-Group` tries `summarize-docs`
2. Lambda invokes `authorize_action(event)`
3. OPA or GREEN map: `allow=false`, `deny_reason="action summarize-docs is not enabled for group Some-Other-Group"`
4. Lambda returns HTTP 403:
   ```json
   {
     "statusCode": 403,
     "body": "{\"error\": \"action summarize-docs is not enabled for group Some-Other-Group\"}"
   }
   ```
5. Logged to CloudWatch: `{"event":"action_err","status":403,"reason":"...","action":"summarize-docs"}`

---

## Deployment Checklist

- [x] Deploy 6 Lambda functions via CloudFormation (`./deploy.sh`)
- [x] Publish resolved catalog to S3 (`s3://vaultmesh-knowledge-base/actions/catalog.json`)
- [x] Smoke-test authorized invocation (VaultMesh-Engineering → allow)
- [x] Smoke-test unauthorized invocation (Some-Other-Group → deny)
- [x] Verify structured logs in CloudWatch Logs
- [x] Add Actions metric widget to VaultMesh-Sovereign dashboard
- [x] Create persona resolution helper (`scripts/persona-helper.sh`)
- [ ] Wire chat UI to call helper (or equivalent API wrapper)
- [ ] Enable OPA endpoint (optional; currently using GREEN fallback)
- [ ] Switch app to SSO (`AWS_IAM_IDC`) for group-scoped guardrails

---

## Testing

### Manual Invocation (CLI)

**Authorized:**
```bash
./scripts/persona-helper.sh invoke \
  summarize-docs \
  alice@vaultmesh.io \
  VaultMesh-Engineering \
  '{"documentUris":["s3://vaultmesh-knowledge-base/convergence/manifesto.md"],"audience":"engineering"}'
```

**Unauthorized:**
```bash
aws lambda invoke \
  --function-name vmq-summarize-docs \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"summarize-docs","user":{"id":"eve@example.com","group":"Unknown-Group"},"params":{"documentUris":["s3://test/doc.md"]}}' \
  /tmp/out.json \
  --region eu-west-1
```

### Logs Query (CloudWatch Logs Insights)

**Find all successful actions (last 1h):**
```
fields @timestamp, action, user.group, request_id
| filter event = "action_ok"
| sort @timestamp desc
| limit 50
```

**Find all denied actions:**
```
fields @timestamp, action, user.group, reason
| filter event = "action_err" and status = 403
| sort @timestamp desc
| limit 50
```

---

## Rollout & Rollback

### Feature Flag per Action

Edit `catalog.json` to add an `enabled` field:
```json
{
  "id": "summarize-docs",
  "enabled": true,
  "safetyTier": "GREEN",
  ...
}
```

**Dark launch:** Set `enabled=false`, deploy catalog to S3. UI/helper skips the action.

**Go live:** Set `enabled=true`, re-upload catalog.

**Rollback:** Set `enabled=false` again. Lambdas remain deployed but unreachable via catalog.

### Canary Deployment

Use Lambda **Aliases** and **Versions**:
```bash
# Publish new version
aws lambda publish-version --function-name vmq-summarize-docs

# Create canary alias (10% traffic)
aws lambda create-alias --function-name vmq-summarize-docs \
  --name canary \
  --routing-config AdditionalVersionWeights={"2"=0.1} \
  --function-version 1
```

Update catalog to point to `arn:...:function:vmq-summarize-docs:canary`.

---

## Next Steps (Roadmap)

### Immediate (Week 1)
- [ ] Wire chat UI to invoke actions via helper or API gateway
- [ ] Test all 6 actions end-to-end
- [ ] Document action input/output contracts for each stub

### Short-term (Weeks 2-4)
- [ ] Implement **real logic** for:
  - `summarize-docs`: Call Bedrock with doc context
  - `generate-faq`: Extract Q&A from folder
  - `draft-change-note`: Diff two S3 objects
  - `validate-schema`: DTDL/NGSI-LD validation
  - `create-jira-draft`: Build Jira issue JSON
  - `compliance-pack`: ZIP bundle with cover sheet
- [ ] Add **approval workflow** (SNS → Slack for `approval_required=true` actions)
- [ ] Enable OPA endpoint for centralized policy
- [ ] Switch Q app to SSO (`AWS_IAM_IDC`)

### Medium-term (Q1 2025)
- [ ] Add **YELLOW**-tier actions (write to Jira, trigger pipelines)
- [ ] Memory layer: store action results in DynamoDB for follow-up queries
- [ ] Metering: track action costs per user/group
- [ ] Federation: cross-account action invocation (Sovereign Mesh)

---

## References

- **Actions Catalog:** `s3://vaultmesh-knowledge-base/actions/catalog.json`
- **Personas:** `s3://vaultmesh-knowledge-base/personas/{engineer,delivery-manager,compliance}.json`
- **OPA Policy:** `02-qbusiness/guardrails/opa/actions.rego`
- **Lambda Handlers:** `03-lambdas/vmq-*/handler.py`
- **Common Library:** `03-lambdas/common/vmq_common.py`
- **Helper Script:** `scripts/persona-helper.sh`
- **CloudFormation Stack:** `vmq-actions-rubedo`
- **Dashboard:** [VaultMesh-Sovereign](https://console.aws.amazon.com/cloudwatch/deeplink.js?region=eu-west-1#dashboards:name=VaultMesh-Sovereign)

---

## Support & Contact

- **Issues:** GitHub (private repo)
- **Ops Runbooks:** `RUNBOOK-IR.md`, `RUNBOOK-DR.md`
- **Convergence Philosophy:** `convergence/manifesto.md`

**END OF RUBEDO INTEGRATION GUIDE**
