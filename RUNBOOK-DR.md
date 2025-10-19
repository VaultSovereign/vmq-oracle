# Disaster Recovery Runbook — VaultMesh Q Business

## Objective
Ensure continuity of the VaultMesh Q Business knowledge experience by validating staged artifacts, promoting healthy builds, and restoring service after disruption.

## Prerequisites
- Access to GitHub Actions “DR Monthly” workflow.
- Permissions to view and promote S3 objects in both `root/` and `_staging/` prefixes.
- CloudWatch dashboard access for observability metrics.

## DR monthly drill procedure

1. **Kickoff**
   - Navigate to GitHub Actions → “DR Monthly”.
   - Dispatch the workflow using the latest commit SHA.
   - Record start time in the drill log.

2. **Staged document verification**
   - After CodeBuild completes, inspect `_staging/` prefix for updated artifacts.
   - Compare object counts against production `root/` prefix using S3 Inventory or `aws s3 ls`.
   - Review generated parity report artifact.

3. **Promotion**
   - Execute promote step via GitHub Actions or run `make promote-dr` locally.
   - Confirm `_staging/` manifests copy into `root/` without drift.
   - Validate audit record at `s3://<bucket>/audit/promotions/promotion-<timestamp>.json`.

4. **Post-promotion validation**
   - Run `make wait-sync` to ensure downstream syncs succeed.
   - Check CloudWatch dashboard single-value widgets for SyncFailed=0, NoSync=0.
   - Perform smoke test queries in the Web Experience.

5. **Close-out**
   - Log drill duration and findings in `RUNBOOK-DR.md` under the latest entry.
   - File issues for remediation tasks (e.g., automation gaps, missing alarms).

## Recovery during an actual incident

1. If primary pipeline fails, trigger DR pipeline using last known good commit.
2. Restore artifacts from `_staging/` to `root/` via promotion step.
3. Run `make sync && make wait-sync` to force reindex.
4. Notify stakeholders and update status page if recovery exceeds 30 minutes.

## Metrics to capture
- Time from kickoff to promotion.
- Parity delta count (expected to be 0).
- Number of manual interventions required.

## Review cadence
- Monthly drills (first business Monday).
- Quarterly tabletop including cross-functional stakeholders.
