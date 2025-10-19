# Rubedo Action Lambdas

Six GREEN-tier actions for Q Business with OPA policy gating and audit logging.

## Architecture

Each Lambda:
- **Validates** input schema
- **Gates** via OPA (`vaultmesh.actions` policy) with static fallback
- **Executes** read-only/draft operation (no side effects)
- **Logs** structured JSON to CloudWatch (action, user, allow/deny)
- **Returns** well-formed response matching catalog schema

## Actions

| Action | Function | Groups | Purpose |
|--------|----------|--------|---------|
| `summarize-docs` | `vmq-summarize-docs` | Engineering, Delivery, Compliance | Multi-doc executive summary |
| `generate-faq` | `vmq-generate-faq` | Engineering, Delivery | FAQ generation from folder |
| `draft-change-note` | `vmq-draft-change-note` | Engineering, Delivery, Management | Change note between versions |
| `validate-schema` | `vmq-validate-schema` | Engineering | DTDL/NGSI-LD schema validation |
| `create-jira-draft` | `vmq-create-jira-draft` | Delivery, Engineering | Jira ticket draft payload |
| `compliance-pack` | `vmq-generate-compliance-pack` | Compliance, Management | Compliance package assembly |

## Deployment

### SAM (recommended)
```bash
cd 03-lambdas
sam build
sam deploy --guided --stack-name vmq-actions
```

### Manual (per function)
```bash
cd vmq-summarize-docs
zip -r ../summarize.zip handler.py
aws lambda create-function \
  --function-name vmq-summarize-docs \
  --runtime python3.12 \
  --handler handler.handler \
  --role arn:aws:iam::ACCOUNT:role/lambda-exec \
  --zip-file fileb://../summarize.zip \
  --environment Variables="{LOG_LEVEL=INFO,EXPORT_BUCKET=vaultmesh-knowledge-base}"
```

## Policy Gating

### OPA Mode (production)
Set `OPA_URL` environment variable:
```bash
OPA_URL=http://opa-service:8181/v1/data/vaultmesh/actions
```

Lambda calls:
- `${OPA_URL}/allow` → boolean
- `${OPA_URL}/approval_required` → boolean
- `${OPA_URL}/deny_reason` → string

### Static Fallback (development)
If `OPA_URL` is unset or unreachable, uses hardcoded GREEN map:
```python
_GREEN = {
    "summarize-docs": {"groups": {"VaultMesh-Engineering", "VaultMesh-Delivery", "VaultMesh-Compliance"}},
    ...
}
```

## Input Contract

All actions expect:
```json
{
  "action": "summarize-docs",
  "user": {
    "id": "alice@vaultmesh.io",
    "group": "VaultMesh-Engineering"
  },
  "context": {
    "request_id": "r-123",
    "persona": "engineer"
  },
  "params": {
    "documentUris": ["s3://..."],
    "audience": "delivery"
  }
}
```

## Testing

Use `test-events.json`:
```bash
aws lambda invoke \
  --function-name vmq-summarize-docs \
  --payload file://test-events.json \
  --cli-binary-format raw-in-base64-out \
  response.json
```

## Logging

Structured CloudWatch logs:
```json
{"event":"action_ok","action":"summarize-docs","request_id":"r-1","user":{"id":"alice@vaultmesh.io","group":"VaultMesh-Engineering"}}
{"event":"action_err","status":403,"reason":"action summarize-docs is not enabled for group VaultMesh-Sales","action":"summarize-docs","user":{"id":"bob@vaultmesh.io","group":"VaultMesh-Sales"}}
```

Query with CloudWatch Insights:
```
fields @timestamp, action, user.id, user.group, event
| filter event = "action_ok"
| stats count() by action
```

## Wiring to Q Business

Update `02-qbusiness/actions/actions-catalog.json` with Lambda ARNs:
```json
{
  "actions": [
    {
      "id": "summarize-docs",
      "arn": "arn:aws:lambda:eu-west-1:ACCOUNT:function:vmq-summarize-docs",
      ...
    }
  ]
}
```

Publish to S3:
```bash
aws s3 cp 02-qbusiness/actions/actions-catalog.json \
  s3://vaultmesh-knowledge-base/actions/catalog.json
```

## Upgrade Path

1. **Add real I/O**: Replace stub logic with S3 reads, API calls
2. **Add OPA sidecar**: Deploy OPA container alongside Lambdas
3. **Add metrics**: Emit custom CloudWatch metrics for invocation counts
4. **Add approval flow**: Wire YELLOW-tier actions to SNS → human approval
5. **Add RED-tier**: Implement side-effect actions with dual-approval + audit

## Security

- **No credentials in code**: Use IAM roles for AWS service access
- **No PII in logs**: Redact sensitive fields before logging
- **Policy-first**: All actions gated by OPA or static GREEN map
- **Audit trail**: Every invocation logged with user context
- **Read-only**: GREEN tier has no side effects (draft/preview only)

## Dependencies

- Python 3.12 runtime
- No external packages (uses stdlib only)
- Common layer: `vmq_common.py` (shared across all functions)

## Cost Estimate

Per 1M invocations (128MB, 1s avg):
- Lambda compute: ~$0.20
- CloudWatch Logs: ~$0.50
- Total: **~$0.70/1M invocations**

## Support

- **Runbook**: `OPERATIONS-RUNBOOK.md`
- **Incident Response**: `RUNBOOK-IR.md`
- **OPA Policies**: `02-qbusiness/guardrails/opa/actions.rego`
