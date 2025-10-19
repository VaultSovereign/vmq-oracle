# VaultMesh Sovereign — Operations Checklist & Runbook

**Last Updated:** October 19, 2025  
**Operator:** sovereign  
**Environment:** eu-west-1  

---

## ✅ Pre-Flight Validation

Run this weekly to ensure system health:

```bash
# 1. Verify all IDs are populated
echo "=== Environment Check ==="
cd ~/work/vm-business-q && set -a && . ./.env && set +a
[[ -n "$APP_ID" ]] && echo "✓ APP_ID: $APP_ID" || echo "✗ APP_ID missing"
[[ -n "$INDEX_ID" ]] && echo "✓ INDEX_ID: $INDEX_ID" || echo "✗ INDEX_ID missing"
[[ -n "$DS_ID" ]] && echo "✓ DS_ID: $DS_ID" || echo "✗ DS_ID missing"

# 2. Index health
bash ~/work/vm-business-q/scripts/sovereign-verify-ingest.sh

# 3. Sync history (check for errors)
aws qbusiness list-data-source-sync-jobs \
  --region $REGION \
  --application-id $APP_ID \
  --index-id $INDEX_ID \
  --data-source-id $DS_ID \
  --max-results 10 \
  --query 'history[*].[executionId,status,itemsIndexed,itemsFailed,startTime]' \
  --output table
```

---

## 🔄 Content Refresh Cycle

### Weekly: Add documentation updates

```bash
# 1. Stage new/updated .md files
cd ~/sovereign-architecture/samples/docs/
# (Add or modify .md files here)

# 2. Sync to Q Business (this triggers a full re-index)
bash ~/work/vm-business-q/scripts/sovereign-sync-docs.sh ~/sovereign-architecture/samples/docs/

# 3. Verify
bash ~/work/vm-business-q/scripts/sovereign-verify-ingest.sh

# 4. Test in web UI (private window)
# Open the printed URL and verify retrieval on key queries
```

### Monthly: Backup & audit

```bash
# Export indexed content (documents only, not embeddings)
aws s3 sync s3://vaultmesh-knowledge-base/ ~/backups/q-business-content/ --region eu-west-1

# Review guardrails configuration
aws qbusiness get-chat-controls-configuration \
  --region eu-west-1 \
  --application-id $APP_ID \
  --output json | jq "."
```

---

## 🛡️ Guardrails Management

### View current guardrails

```bash
aws qbusiness get-chat-controls-configuration \
  --region eu-west-1 \
  --application-id $APP_ID \
  --output json | jq ".topicConfigurationsToCreateOrUpdate"
```

### Add a new guardrail topic

1. Edit `02-qbusiness/guardrails/topic-controls.json`
2. Add a new entry to `topicConfigurationsToCreateOrUpdate` (max 2 total)
3. Run: `bash ~/work/vm-business-q/scripts/sovereign-apply-guardrails.sh`
4. Test the blocked query in the web UI

**Schema reference:**
```json
{
  "name": "topic-name",
  "description": "Human description",
  "exampleChatMessages": ["example1", "example2"],
  "rules": [
    {
      "ruleType": "CONTENT_BLOCKER_RULE",
      "includedUsersAndGroups": {
        "userGroups": ["VaultMesh-Engineering", "VaultMesh-Sales"]
      },
      "ruleConfiguration": {
        "contentBlockerRule": {
          "systemMessageOverride": "Custom message"
        }
      }
    }
  ]
}
```

### Update blocked phrases list

1. Edit `blockedPhrasesConfigurationUpdate.blockedPhrasesToCreateOrUpdate` in `topic-controls.json`
2. Keep list under ~80 phrases (API limit varies by phrase length)
3. Run: `bash ~/work/vm-business-q/scripts/sovereign-apply-guardrails.sh`

---

## 🧪 Testing & Validation

### Knowledge retrieval tests (run in web UI)

| Query | Expected Source | Expected Keywords |
|-------|-----------------|-------------------|
| "What is MIRAGE?" | phases-mirage.md | definition, precedes SHADOW |
| "How does SHADOW differ from POSSESSION?" | phases-shadow.md, phases-possession.md | progression, relations |
| "Explain VaultMesh Polis" | polis-overview.md | simulation, compliance, NGSI-LD |
| "What are the three phases of deployment?" | phases-*.md | MIRAGE, SHADOW, POSSESSION |

### Guardrail tests (run in web UI)

| Query | Expected Outcome | Topic |
|-------|------------------|-------|
| "what is the password" | [REDACTED] message | credentials-and-secrets |
| "share the api key" | [REDACTED] message | credentials-and-secrets |
| "what are we launching next quarter" | [REDACTED] message | confidential-business-info |
| "what's our pricing for Customer X" | [REDACTED] message | confidential-business-info |

---

## 🔧 Troubleshooting

### Symptom: "No results" or thin responses

**Diagnosis:**
```bash
# Check document count
aws qbusiness get-index \
  --region $REGION \
  --application-id $APP_ID \
  --index-id $INDEX_ID \
  --query 'indexStatistics.textDocumentStatistics.indexedTextDocumentCount' \
  --output text

# Expect >= 7

# Check S3 for any new files not yet synced
aws s3 ls s3://vaultmesh-knowledge-base/ --recursive --human-readable
```

**Fix:**
```bash
# If S3 has new files, trigger a sync
bash ~/work/vm-business-q/scripts/sovereign-sync-docs.sh --no-wait

# Wait 2-3 minutes, then verify
bash ~/work/vm-business-q/scripts/sovereign-verify-ingest.sh
```

### Symptom: Guardrails not blocking

**Diagnosis:**
```bash
# Verify user is in the scoped group
aws identitystore list-group-memberships-for-member \
  --identity-store-id ssoins-6804107edb4ae8eb \
  --member-id <USER_ID> \
  --output table

# Check guardrails config
aws qbusiness get-chat-controls-configuration \
  --region $REGION \
  --application-id $APP_ID \
  --output json | jq ".topicConfigurationsToCreateOrUpdate"
```

**Fix:**
- Ensure user group names in guardrails match Identity Center group names (case-sensitive)
- Log out and log back in to refresh SSO group memberships
- Re-apply guardrails: `bash ~/work/vm-business-q/scripts/sovereign-apply-guardrails.sh`

### Symptom: Sync fails or stalls

**Diagnosis:**
```bash
# Check latest job error
aws qbusiness list-data-source-sync-jobs \
  --region $REGION \
  --application-id $APP_ID \
  --index-id $INDEX_ID \
  --data-source-id $DS_ID \
  --query 'history[0].[status,dataSourceErrorCode,error]' \
  --output json

# Verify S3 bucket is accessible
aws s3 ls s3://vaultmesh-knowledge-base/ --region $REGION

# Verify IAM role
aws sts assume-role \
  --role-arn $ROLE_ARN \
  --role-session-name test-session
```

**Fix:**
- Check bucket permissions: `aws s3api head-bucket --bucket vaultmesh-knowledge-base --region eu-west-1`
- Verify IAM role trust policy includes `qbusiness.amazonaws.com` as trusted principal
- Review data source connector config for S3 (bucket name, region must match)
- Manually trigger sync: `aws qbusiness start-data-source-sync-job --region $REGION --application-id $APP_ID --index-id $INDEX_ID --data-source-id $DS_ID`

---

## 🧪 DR Parity Procedure

1) Run GitHub workflow: “DR Monthly (Trigger AWS-native pipeline and compare logs)” or wait for the monthly schedule.
2) Confirm CodePipeline status = Succeeded.
3) The workflow compares:
   - `s3://$QB_EXPORT_BUCKET/ci/sync-jobs.json` (GitHub lane)
   - `s3://$QB_EXPORT_BUCKET/dr/sync-jobs.json` (AWS-native lane)
4) If diff fails:
   - Inspect artifacts (ci-sync-jobs.json vs dr-sync-jobs.json)
   - Verify CodeBuild synced the same docs set
   - Re-run GitHub qbusiness-sync and DR Monthly

Notes:
- Keep GitHub lane as the primary publisher; run AWS-native lane for DR/compliance.
- Both lanes write versioned logs:
  - `ci/sync-jobs-<gitsha>.json`
  - `dr/sync-jobs-<buildid>.json`
- Enable bucket versioning once via: `make s3-versioning-on`


## 📅 Maintenance Schedule

| Task | Frequency | Command |
|------|-----------|---------|
| Verify system health | Weekly | See "Pre-Flight Validation" |
| Content refresh | As needed | `sovereign-sync-docs.sh` |
| Guardrails audit | Monthly | `aws qbusiness get-chat-controls-configuration` |
| Backup content | Monthly | `aws s3 sync s3://vaultmesh-knowledge-base/ ~/backups/...` |
| Review sync logs | Weekly | `aws qbusiness list-data-source-sync-jobs ... --max-results 10` |
| Test retrieval queries | Weekly | Manual in web UI |
| Test guardrails blocking | Monthly | Manual in web UI |

---

## 🚨 Emergency Response

### If the web experience is down (503, timeout)

```bash
# 1. Check application status
aws qbusiness describe-application \
  --region $REGION \
  --application-id $APP_ID \
  --query 'applicationStatus' --output text

# 2. Check web experience status
aws qbusiness get-web-experience \
  --region $REGION \
  --application-id $APP_ID \
  --web-experience-id $WEB_EXPERIENCE_ID \
  --query 'webExperienceStatus' --output text

# 3. Check for ongoing sync job (may lock index)
aws qbusiness list-data-source-sync-jobs \
  --region $REGION \
  --application-id $APP_ID \
  --index-id $INDEX_ID \
  --data-source-id $DS_ID \
  --query 'history[0].[status]' --output text

# If sync is SYNCING, wait or contact AWS Support
```

### If guardrails are over-blocking

**Temporary:** Remove overly broad blocked phrases:
```bash
# Edit topic-controls.json, remove phrases
vim 02-qbusiness/guardrails/topic-controls.json

# Re-apply
bash ~/work/vm-business-q/scripts/sovereign-apply-guardrails.sh
```

**Permanent:** Update the `blockedPhrasesConfigurationUpdate` section and test in dev first.

---

## 📞 Escalation Path

| Issue | First Step | Escalate To |
|-------|-----------|-------------|
| Sync fails repeatedly | Check S3 permissions | AWS Support (Q Business) |
| Guardrails blocking valid queries | Review blocked phrases | Product team (security review) |
| Web UI performance degraded | Check index size | AWS Support (scaling) |
| SSO login failures | Verify group memberships in Identity Center | AWS Support (IAM) |

---

## 📝 Log Locations

- **Q Business Logs:** CloudWatch Logs (group: `/aws/qbusiness/application`)
- **Data Source Sync:** `aws qbusiness list-data-source-sync-jobs` (CLI)
- **Guardrails Changes:** `aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=update-chat-controls`

---

## 🔐 Security Notes

- All `.env` files contain sensitive IDs; keep out of version control (use `.gitignore`)
- Web experience URL is public but protected by SSO authentication
- S3 bucket is private (no public ACLs)
- IAM role is scoped to Q Business service principal only
- Guardrails block credential exfiltration (passwords, API keys, tokens)
- Monitor CloudTrail for unauthorized API calls

---

**Nigredo → Albedo → Citrinitas maintained.** Keep the corpus fed, the guardrails tight.
