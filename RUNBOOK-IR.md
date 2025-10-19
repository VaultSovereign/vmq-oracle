# Incident Response Runbook — VaultMesh Oracle

**Purpose:** Operational playbooks for responding to Oracle guardrail and sync incidents.

---

## Incident: Guardrail Drift Detected

**Trigger:** `guardrail-drift.yml` workflow fails; Slack/email alert from GitHub Actions.

**Severity:** **HIGH** — Production guardrails have diverged from source of truth.

### Immediate Actions (< 5 min)

1. **Check the workflow run:**
   ```bash
   # Navigate to Actions → Guardrail Drift → most recent failed run
   # Review the drift.patch output in the logs
   ```

2. **Download evidence from S3:**
   ```bash
   export REGION=eu-west-1
   export AUDIT_BUCKET=<from secrets>

   # Find the latest drift timestamp
   aws s3 ls "s3://${AUDIT_BUCKET}/audit/drift/" --region $REGION | tail -n 4

   # Download evidence (replace TIMESTAMP)
   aws s3 cp "s3://${AUDIT_BUCKET}/audit/drift/guardrail-drift-TIMESTAMP.json" ./
   aws s3 cp "s3://${AUDIT_BUCKET}/audit/drift/guardrail-local-TIMESTAMP.json" ./
   aws s3 cp "s3://${AUDIT_BUCKET}/audit/drift/guardrail-remote-TIMESTAMP.json" ./
   aws s3 cp "s3://${AUDIT_BUCKET}/audit/drift/guardrail-diff-TIMESTAMP.patch" ./
   ```

3. **Verify git provenance:**
   ```bash
   # Extract git_sha from metadata
   cat guardrail-drift-TIMESTAMP.json | jq -r '.git_sha'

   # Confirm it matches expected HEAD
   git log -1 --oneline
   ```

### Root Cause Analysis (< 15 min)

**Question 1:** Was the remote configuration changed manually in AWS Console?
- Check CloudTrail for `UpdateChatControlsConfiguration` API calls:
  ```bash
  aws cloudtrail lookup-events --region $REGION \
    --lookup-attributes AttributeKey=EventName,AttributeValue=UpdateChatControlsConfiguration \
    --max-results 5 --query 'Events[*].[EventTime,Username]' --output table
  ```

**Question 2:** Was the local source file changed without merging to `master`?
- Check git history for uncommitted or unmerged changes:
  ```bash
  git status
  git diff HEAD 02-qbusiness/guardrails/topic-controls.json
  ```

**Question 3:** Is there a race condition (recent commit not yet reflected in CI)?
- Compare the `git_sha` in evidence with current HEAD
- If mismatch: wait 5 minutes and re-run workflow

### Remediation

**Scenario A: Manual console change (unauthorized)**
1. Revert remote to source of truth:
   ```bash
   make guardrails  # Applies local topic-controls.json to remote
   ```
2. File incident report; review CODEOWNERS enforcement
3. Enable CloudTrail alerting for `UpdateChatControlsConfiguration` (if not already active)

**Scenario B: Local source changed without PR**
1. Create a PR with the local changes
2. Ensure Guardrail Lint workflow passes
3. Merge after review by `@VaultSovereign/security`

**Scenario C: Race condition (benign)**
1. Re-run the workflow manually
2. Confirm it passes
3. No further action needed

### Post-Incident

- [ ] Document root cause in incident log
- [ ] Tag S3 evidence objects with incident ID:
  ```bash
  aws s3api put-object-tagging --bucket "${AUDIT_BUCKET}" \
    --key "audit/drift/guardrail-drift-TIMESTAMP.json" \
    --tagging "TagSet=[{Key=incident_id,Value=INC-2025-XXX}]"
  ```
- [ ] Update CODEOWNERS or branch protection if governance gap found
- [ ] Review S3 evidence retention (default: indefinite; consider lifecycle rule if needed)
- [ ] Communicate resolution to #vaultmesh-ops with evidence links

---

## Incident: Sync Failed > 24h

**Trigger:** `no-sync-daily.yml` workflow fails; SNS alarm fires.

**Severity:** **MEDIUM** — Knowledge base is stale; user queries may return outdated info.

### Immediate Actions (< 5 min)

1. **Check last sync job status:**
   ```bash
   export REGION=eu-west-1
   export APP_ID=<from .env>
   export INDEX_ID=<from .env>
   export DS_ID=<from .env>

   aws qbusiness list-data-source-sync-jobs \
     --region $REGION --application-id $APP_ID \
     --index-id $INDEX_ID --data-source-id $DS_ID \
     --max-results 5 --output table
   ```

2. **Review sync failure logs:**
   ```bash
   # Check most recent sync job details
   aws qbusiness list-data-source-sync-jobs \
     --region $REGION --application-id $APP_ID \
     --index-id $INDEX_ID --data-source-id $DS_ID \
     --max-results 1 --query 'history[0].[executionId,status,errorMessage]' --output table
   ```

3. **Verify S3 bucket permissions:**
   ```bash
   # Ensure data source role can read the knowledge bucket
   aws s3 ls s3://vaultmesh-knowledge-base/ --region $REGION
   ```

### Root Cause Analysis

**Common causes:**
- S3 bucket permissions changed (data source role lacks `s3:GetObject`)
- Large document upload exceeded timeout
- Q Business service throttling (rare)
- Data source connector misconfigured

### Remediation

1. **Retry sync manually:**
   ```bash
   cd ~/work/vmq-oracle  # or wherever repo lives
   make sync
   # Monitor progress
   watch -n 10 'aws qbusiness list-data-source-sync-jobs --region $REGION --application-id $APP_ID --index-id $INDEX_ID --data-source-id $DS_ID --max-results 1 --query "history[0].status"'
   ```

2. **If sync fails again:**
   - Check CloudWatch Logs for Q Business data source errors
   - Verify connector JSON matches AWS docs: [02-qbusiness/datasources/s3-ds.json](02-qbusiness/datasources/s3-ds.json)
   - Review bucket policy and IAM role trust relationship

3. **Escalate if persistent (>3 failures):**
   - Contact AWS Support with execution IDs
   - Review Q Business service health dashboard

### Post-Incident

- [ ] Document root cause and resolution steps
- [ ] If SNS alert didn't fire, verify `ALERT_SNS_TOPIC_ARN` secret is configured
- [ ] Update connector configuration if drift found
- [ ] Communicate resolution timeline to stakeholders

---

## Branch Protection & Required Checks

To enforce guardrail governance, configure branch protection on `master`:

**Required status checks:**
- `Guardrail Lint`
- `Guardrail Drift` (optional; may run post-merge)

**Required reviewers:**
- Files in `02-qbusiness/guardrails/*` require approval from `@VaultSovereign/security`
- Files in `.github/workflows/*` require approval from `@VaultSovereign/ops`

**Enable:**
1. GitHub → Settings → Branches → Branch protection rules → Add rule
2. Branch name pattern: `master`
3. ✅ Require status checks to pass before merging
   - Select: `Guardrail Lint`
4. ✅ Require review from Code Owners
5. Save changes

---

**Last Updated:** October 19, 2025
**Maintained by:** VaultSovereign/sovereign-ops
