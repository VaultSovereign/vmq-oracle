# 7-Day Sprint: Oracle B+ → A Grade Readiness

**Start Date:** October 19, 2025
**Target Completion:** October 26, 2025
**Sprint Goal:** Elevate VaultMesh Oracle from prototype to production-ready fintech setup

---

## P0/P1 Fixes Status (COMPLETED ✅)

### Merge Conflict Resolution
- [x] **Resolved** merge conflict in `docs/fintech-production-hardening.md` — "Setup, Not Product" version committed
- [x] **Verified** guardrail drift workflow uses single `topic-controls.json` source
- [x] **Confirmed** README contains only canonical guardrail link (line 57)
- [x] **Validated** Makefile YAML-first/JSON fallback logic (lines 55-64)
- [x] **Checked** CODEOWNERS file exists with proper security/ops coverage
- [x] **Confirmed** branch protection guidance exists at `.github/BRANCH-PROTECTION.md`

### Next Actions
- [ ] **Enable branch protection** on `master` per `.github/BRANCH-PROTECTION.md`
- [ ] **Trigger workflows** manually to populate status check dropdown:
  ```bash
  gh workflow run guardrail-lint.yml
  gh workflow run guardrail-drift.yml
  ```
- [ ] **(Optional)** Create pre-commit hook for local guardrail validation:
  ```bash
  mkdir -p githooks
  # Create pre-commit script (see template below)
  chmod +x githooks/pre-commit
  ln -s ../../githooks/pre-commit .git/hooks/pre-commit
  ```

---

## Sprint Backlog by Day

### Day 1–2: Phase 0 — Foundation (Unblocks Multi-Account)

**Goal:** Eliminate `.env` files and hard-coded paths; establish per-environment metadata

#### Tasks
- [ ] **Create environment manifests**
  - Create `env/dev.yaml`, `env/staging.yaml`, `env/prod.yaml`
  - Schema: `{account_id, region, app_id, index_id, ds_id, export_bucket, kms_key_id}`
  - Store in repo as templates; sensitive values → SSM Parameter Store

- [ ] **Migrate to SSM Parameter Store**
  ```bash
  # For each environment (dev/staging/prod):
  aws ssm put-parameter --name "/vaultmesh/dev/app_id" \
    --value "a1b2c3..." --type SecureString --region eu-west-1
  aws ssm put-parameter --name "/vaultmesh/dev/index_id" \
    --value "x7y8z9..." --type SecureString --region eu-west-1
  # Repeat for: ds_id, export_bucket, kms_key_id, region
  ```

- [ ] **Update CI workflows** to fetch from SSM instead of GitHub Secrets
  - Replace `${{ secrets.QB_APP_ID }}` with SSM fetch step
  - Add session tags: `vaultmesh:env=$ENV`, `vaultmesh:purpose=ci-sync`

- [ ] **Refactor scripts** to use `git rev-parse --show-toplevel` instead of `$HOME/work/vmq-oracle`
  - Update: `scripts/sovereign-sync.sh:9`
  - Pattern: `REPO_ROOT=$(git rev-parse --show-toplevel)`

- [ ] **Scope OIDC trust policies** per environment
  - Generate per-env roles: `GitHubActions-QBusiness-Dev`, `-Staging`, `-Prod`
  - Trust policy condition: `"token.actions.githubusercontent.com:sub": "repo:VaultSovereign/vmq-oracle:ref:refs/heads/main"`
  - Add permission boundaries to prevent cross-env escalation

**Acceptance Criteria:**
- No `.env` files in CI workflows or scripts
- All environment-specific values resolved from SSM Parameter Store
- OIDC roles scoped to specific branches/tags with session tags enforced

---

### Day 3–4: Phase 1 — Deterministic Handlers (Close Compliance Gap)

**Goal:** Replace placeholder Lambdas with production-ready validation/redaction/OPA enforcement

#### Tasks
- [ ] **Implement schema validation**
  - Add Pydantic models or JSON Schema validators to Lambda handlers
  - Example: `03-lambdas/*/handler.py` → validate all payloads before processing

- [ ] **Add PII redaction**
  - Implement deterministic PII scrubbing (PAN, SSN, email, tokens)
  - Use libraries: `scrubadub` (Python) or custom regex patterns
  - Log redaction actions with hash digests for audit trail

- [ ] **Enforce fail-closed OPA policy**
  - Current: Falls back to "green map" when OPA unreachable
  - Target: Return HTTP 403 and log denial when OPA unavailable or returns `allow: false`
  - Require explicit `allow: true` response from OPA before processing

- [ ] **Structured audit logging**
  - Emit JSON logs with fields: `{request_id, tenant, action, decision, input_hash, opa_response, timestamp}`
  - Configure CloudWatch Logs retention: **400 days minimum**
  - Mirror logs to S3 bucket with Object Lock (COMPLIANCE mode, 400-day retention)

- [ ] **Unit & contract tests**
  - Expand `03-lambdas/test-events.json` with:
    - Positive cases: valid payloads with PII → expect redacted output
    - Negative cases: invalid schema, missing OPA allow → expect 400/403
  - Integrate tests in CI: `make lambdas-test` must pass before deployment

**Acceptance Criteria:**
- All Lambda handlers validate input schemas (no unstructured payloads processed)
- PII redaction is deterministic and auditable
- OPA deny-by-default enforced (no fallback to permissive behavior)
- Structured logs shipped to CloudWatch + immutable S3 with 400-day retention
- Test coverage ≥80% for handler logic

---

### Day 5: Phase 2 — Observability & Guardrail Enforcement

**Goal:** Make SLOs enforceable and guardrail drift actionable

#### Tasks
- [ ] **Enforce sync SLO with evidence**
  - Update `.github/workflows/no-sync-daily.yml`:
    - Compute elapsed time since last sync
    - Fail workflow if >24 hours
    - Generate signed evidence artifact: `{ts, breach: "sync_slo", last_sync_time, git_sha}`
    - Upload to `s3://$QB_EXPORT_BUCKET/audit/incidents/sync-slo-breach-{ts}.json`
    - Publish to SNS topic: `$ALERT_SNS_TOPIC_ARN` (configure in GitHub Secrets if not set)

- [ ] **CloudWatch metric filters**
  - Create filter for Lambda logs: `outcome: "denied"` → metric `VaultMesh/OPA/Denials`
  - Create filter for sync jobs: `status: "FAILED"` → metric `VaultMesh/Sync/Failures`
  - Create filter for SLO breaches: `breach: "sync_slo"` → metric `VaultMesh/SLO/Breaches`

- [ ] **Alarms & dashboards**
  - Create CloudWatch Alarms:
    - `VaultMesh-OPA-Denial-Spike`: Denials > 10/5min
    - `VaultMesh-Sync-SLO-Breach`: SLO breach detected
    - `VaultMesh-Lambda-ErrorRate`: Error rate > 1%
  - Wire alarms to SNS topic → PagerDuty/on-call rotation
  - Update dashboard (`02-qbusiness/monitoring/qbusiness-dashboard.json.tmpl`) to include:
    - OPA denial rate graph
    - Lambda p95 latency
    - Sync freshness timeline

**Acceptance Criteria:**
- No-Sync Daily workflow fails (not just warns) when SLO breached
- Breach evidence uploaded to immutable S3 with git SHA and timestamp
- CloudWatch alarms trigger on OPA denials, SLO breaches, Lambda errors
- Dashboards show real-time compliance metrics

---

### Day 6: Phase 3 — DR Discipline

**Goal:** Validate disaster recovery process and create evidence automation

#### Tasks
- [ ] **Manual DR test**
  - Trigger DR Monthly workflow: `gh workflow run dr-monthly.yml`
  - Verify:
    - Terminal-state loop completes (no infinite wait)
    - Promotion audit artifact generated
    - S3 evidence uploaded with dual-approval metadata

- [ ] **Document DR promotion flow**
  - Add section to `RUNBOOK-DR.md`:
    - Prerequisites: two approvers from `@VaultSovereign/ops`
    - Procedure: manual approval step before promotion
    - Evidence collection: `{approver_1, approver_2, git_sha, timestamp, artifact_hash}`
    - Rollback procedure

- [ ] **Schedule quarterly DR tests**
  - Add calendar entry: "VaultMesh DR Exercise — Quarterly"
  - Owner: `@VaultSovereign/ops`
  - Checklist: Run DR workflow, verify dual approvals, notarize evidence

- [ ] **Verify Object Lock on audit bucket**
  ```bash
  aws s3api get-object-lock-configuration --bucket $QB_EXPORT_BUCKET
  # Should show: Mode=COMPLIANCE, RetentionDays=400
  # If not configured, apply:
  aws s3api put-object-lock-configuration --bucket $QB_EXPORT_BUCKET \
    --object-lock-configuration 'ObjectLockEnabled=Enabled,Rule={DefaultRetention={Mode=COMPLIANCE,Days=400}}'
  ```

**Acceptance Criteria:**
- DR Monthly workflow runs successfully end-to-end
- Promotion requires dual approval with evidence capture
- Audit bucket has Object Lock enabled (COMPLIANCE mode)
- Quarterly DR test scheduled and documented

---

### Day 7: Docs & Governance

**Goal:** Finalize documentation and governance artifacts

#### Tasks
- [ ] **Create SECURITY.md**
  - Security policy: responsible disclosure, supported versions
  - Escalation: `security@vaultsovereign.com` or GitHub private advisory
  - Compliance: mention PCI DSS/SOC 2 alignment

- [ ] **Update CODEOWNERS** to include:
  ```
  /SECURITY.md                             @VaultSovereign/security
  /env/**                                  @VaultSovereign/ops
  /03-lambdas/**                           @VaultSovereign/engineering @VaultSovereign/security
  ```

- [ ] **Document guardrail drift incident drill**
  - Add section to `RUNBOOK-IR.md`:
    - Scenario: Guardrail Drift detected by hourly workflow
    - Detection: Check `s3://$QB_EXPORT_BUCKET/audit/drift/` for latest evidence
    - Response: Compare local vs remote, identify unauthorized change
    - Remediation: Reapply canonical config via `make guardrails`, document approval
    - Evidence: Link to drift patch, remediation PR, approval signatures

- [ ] **Finalize hardening doc**
  - Ensure `docs/fintech-production-hardening.md` references this sprint plan
  - Update "Definition of Done" section to reflect completed items

- [ ] **Enable branch protection**
  - Follow `.github/BRANCH-PROTECTION.md` step-by-step
  - Required checks: `Guardrail Lint` (mandatory)
  - Optional checks: `No-Sync Daily`, `DR Monthly Parity`
  - Require CODEOWNERS approval

**Acceptance Criteria:**
- SECURITY.md exists and is covered by CODEOWNERS
- RUNBOOK-IR.md contains guardrail drift incident drill with evidence links
- Branch protection active with required checks and CODEOWNERS enforcement
- All documentation updated to reflect production-ready state

---

## A-Grade Readiness Checklist

Use this to verify sprint completion:

### Identity & Access
- [ ] Per-environment SSM parameters for all AWS resource IDs
- [ ] OIDC roles scoped to branches/tags with session tags
- [ ] Permission boundaries or SCPs prevent cross-environment escalation
- [ ] No `.env` files in CI workflows

### Deterministic Controls
- [ ] Lambda handlers validate all inputs (JSON Schema/Pydantic)
- [ ] PII redaction implemented and tested
- [ ] OPA fail-closed enforced (no permissive fallback)
- [ ] Structured audit logs → CloudWatch + S3 Object Lock (400-day retention)

### Observability & Evidence
- [ ] Sync SLO enforced with automatic alerts and evidence capture
- [ ] Guardrail drift detection active with immutable S3 artifacts
- [ ] CloudWatch dashboards show Lambda errors, OPA denials, sync freshness
- [ ] Alarms wired to on-call rotation (SNS → PagerDuty)

### Compliance Operations
- [ ] DR workflow tested with dual-approval promotion flow
- [ ] Quarterly DR tests scheduled
- [ ] Object Lock enabled on audit bucket (COMPLIANCE mode)
- [ ] Guardrail drift incident drill documented in RUNBOOK-IR.md

### Governance
- [ ] Branch protection active with required checks
- [ ] CODEOWNERS enforced for guardrails, workflows, security docs
- [ ] SECURITY.md published
- [ ] All changes land through peer-reviewed PRs (no direct commits to `master`)

---

## Operator Quick Reference

### Trigger workflows manually
```bash
gh workflow run guardrail-lint.yml
gh workflow run guardrail-drift.yml
gh workflow run no-sync-daily.yml
gh workflow run dr-monthly.yml
```

### Verify SLO breach evidence
```bash
aws s3 ls "s3://$QB_EXPORT_BUCKET/audit/incidents/" --recursive | grep sync-slo
```

### Check guardrail drift
```bash
aws s3 ls "s3://$QB_EXPORT_BUCKET/audit/drift/" --recursive | tail -5
```

### Verify Object Lock
```bash
aws s3api get-object-lock-configuration --bucket $QB_EXPORT_BUCKET
```

### Deploy updated guardrails
```bash
make guardrails
make guardrails-verify
```

---

## Sprint Retrospective Template

After Day 7, capture:

### What Went Well
- [ ] P0/P1 fixes completed without blockers
- [ ] Environment parameterization unlocked multi-account setup
- [ ] Lambda handlers now enforce schema validation and OPA deny-by-default

### What Needs Improvement
- [ ] SSM parameter migration took longer than expected
- [ ] Lambda test coverage gaps remain in edge cases
- [ ] DR workflow requires manual intervention for dual approval

### Action Items
- [ ] Schedule follow-up sprint for Lambda test coverage → 90%
- [ ] Investigate automated dual-approval via GitHub Environments
- [ ] Document edge cases found during Phase 1 testing

---

**Sprint Owner:** VaultSovereign/ops
**Last Updated:** October 19, 2025
**Status:** ACTIVE — P0/P1 ✅ | Sprint Days 1-7 🟡

*Tem approves only when evidence is immutable. Rubedo seal requires all checkboxes green.*
