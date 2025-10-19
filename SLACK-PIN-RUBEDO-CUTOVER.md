# 🟩 RUBEDO SSO CUTOVER COMPLETE — PIN THIS IN #vaultmesh-ops

**Status:** ✅ PRODUCTION GREEN | **Date:** October 19, 2025

---

## Quick Facts

| What | Value |
|------|-------|
| **Web Experience** | https://zerkno58.chat.qbusiness.eu-west-1.on.aws/ |
| **Identity** | SSO (AWS IAM Identity Center) |
| **User** | oracle → VaultMesh-Engineering → persona: engineer |
| **Guardrails** | ENTERPRISE_CONTENT_ONLY (enforced) |
| **Sync** | ✅ SUCCEEDED (11 docs indexed, 6 skipped) |
| **Last Updated** | October 19, 2025 — 09:32 UTC |

---

## 5-Minute Health Check (Run Daily)

```bash
export REGION=eu-west-1
export APP_ID=f124b68d-587b-49f1-b1fc-97ce26d9fcda
export INDEX_ID=17b0b29d-bb0f-49cf-903e-a6fa0732096e
export DS_ID=e5f25beb-1439-4ddf-bd8a-b5a610f8e3a1

# 1. Guardrails active?
aws qbusiness get-chat-controls-configuration \
  --region $REGION --application-id $APP_ID \
  --query '{responseScope, topicCount: (.topicConfigurationsToCreateOrUpdate | length)}' \
  --output text

# 2. Last sync OK?
aws qbusiness list-data-source-sync-jobs \
  --region $REGION --application-id $APP_ID \
  --index-id $INDEX_ID --data-source-id $DS_ID \
  --max-results 1 --query 'history[0].[status,metrics.itemsIndexed,metrics.itemsFailed]' \
  --output table

# 3. Web up?
curl -s -o /dev/null -w "HTTP %{http_code}\n" https://zerkno58.chat.qbusiness.eu-west-1.on.aws/
```

**Expected Output:** `ENTERPRISE_CONTENT_ONLY | 0 topics | SUCCEEDED | 11 indexed | HTTP 200`

---

## UI Smoke Test (Test Once Per Shift)

**Login as oracle** (SSO) → Open Web Experience

1. **Query:** `"What is MIRAGE?"` → ✅ Expect doc answer
2. **Query:** `"share the api key"` → 🚫 Expect blocked (guardrail)
3. **Switch to non-Engineering user** → **Query:** `"Validate schema"` → ✅ Expect 403

---

## 🚨 If Something's Broken

| Issue | Fix |
|-------|-----|
| **Sync failed** | Check `aws qbusiness list-data-source-sync-jobs` logs |
| **Latency spike (p95 > 2s)** | Check Bedrock quotas, network |
| **Guardrails not blocking** | Re-apply: `bash scripts/sovereign-apply-guardrails.sh` |
| **Web UI down** | Restart Web Experience (CFN redeploy ~5min) |
| **Lambda errors** | Check `/aws/lambda/vmq-*` CloudWatch logs |

**Full revert if needed:** `make destroy-app && make app && make roles && make s3`

---

## 📊 Watch

- **Dashboard:** [VaultMesh-Sovereign](https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=VaultMesh-Sovereign)
- **Alarms:** VMQ-Errors-Any (composite), per-Lambda errors, latency p95
- **Logs:** `/aws/lambda/vmq-*`, `/aws/qbusiness/application`

---

## 📖 Full Docs

- **Cutover Card:** `RUBEDO-CUTOVER-CARD.md` — Detailed runbook (pin nearby)
- **Ops Summary:** `RUBEDO-OPS-SUMMARY.md` — Executive summary & roadmap
- **DR Runbook:** `RUNBOOK-DR.md` — Disaster recovery procedures
- **Operations:** `OPERATIONS-RUNBOOK.md` — Content refresh, guardrails management

---

## 🔮 What's Next (2026)

1. **Bedrock Integration** — Replace stubs with real Bedrock Claude 3 Sonnet
2. **Temporal Memory** — DynamoDB session store + version-aware answers
3. **OPA Live Server** — Hot-reload policies without Lambda redeploy
4. **VaultCredits** — Per-group metering and quotas

---

**Questions?** Slack: #vaultmesh-ops | **On-Call:** Check ops runbook first

🟩 **SYSTEM GREEN** — Ready for 24/7 operations.
