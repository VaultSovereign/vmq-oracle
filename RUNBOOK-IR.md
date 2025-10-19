# Incident Response Runbook — VaultMesh Q Business

## Purpose
Provide step-by-step guidance to detect, mitigate, and recover from incidents affecting the Q Business knowledge base, connectors, or web experience.

## Contacts
- **Primary on-call:** `#ops-escalations` Slack channel (rotate weekly)
- **Knowledge Ops lead:** knowledge-ops@vaultmesh.io
- **Security liaison:** security@vaultmesh.io

## Trigger conditions
- “SyncFailed” alarm triggered for more than 15 minutes.
- “NoSync > 24h” alarm triggered.
- Guardrail violations blocking user queries.
- Unauthorized content detected in the index.

## Response workflow

1. **Acknowledge & Triage**
   - Confirm alert receipt in `#ops-escalations`.
   - Identify affected connector, index, or guardrail.
   - Set incident severity (default SEV2; escalate to SEV1 if customer impact).

2. **Stabilize**
   - Disable impacted connector schedule if failures are recurring.
   - For guardrail blocking errors, inspect last deployment commit and revert if necessary.
   - Capture logs: `make logs SYNC_DATA_SOURCE_ID=<id>` or AWS Console CloudWatch insights.

3. **Rollback via S3 versioning**
   - Navigate to the data bucket in AWS Console.
   - Select the impacted object prefix (root or `_staging/`).
   - Use **Latest previous version → Restore** to revert to the last known good artifact.
   - Confirm `StartDataSourceSyncJob` runs with restored objects.

4. **Force resync**
   - Run `make sync && make wait-sync` from the repo root.
   - Monitor the CloudWatch dashboard for SyncFailed errors clearing.
   - For connector-specific resyncs, execute targeted scripts in `scripts/` (e.g., `scripts/sovereign-sync-docs.sh`).

5. **Communicate**
   - Post updates every 30 minutes in `#ops-escalations`.
   - Notify affected stakeholders via email if resolution extends beyond 2 hours.

6. **Validate & Close**
   - Verify user queries succeed in the Web Experience.
   - Ensure alarms reset and dashboards show current data.
   - Record timeline, impact, and remediation in `OPERATIONS-RUNBOOK.md`.

## Post-incident review
- Conduct a 30-minute retro within 5 business days.
- Identify automation opportunities (additional alarms, guardrail tests).
- Update this runbook if steps changed or new tooling added.
