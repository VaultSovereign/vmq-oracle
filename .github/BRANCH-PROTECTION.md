# Branch Protection Configuration

This document provides the recommended GitHub branch protection rules for the `vmq-oracle` repository to enforce guardrail governance and operational safety.

---

## Configuration Steps

### 1. Navigate to Branch Protection Settings

1. Go to repository **Settings** → **Branches**
2. Click **Add branch protection rule**
3. Set **Branch name pattern**: `master` (or `main` if that's your default branch)

---

### 2. Required Status Checks

Enable: **✅ Require status checks to pass before merging**

**Select the following checks:**
- `Guardrail Lint` — validates JSON schema and structure of guardrail files
- _(Optional)_ `Guardrail Drift` — may run post-merge to detect remote drift

**Additional recommended checks:**
- `No-Sync Daily` (if you want to block merges during sync SLO violations)
- `DR Monthly Parity` (if you want to block merges during DR failures)

**Note:** Only checks that have run at least once will appear in the dropdown. Trigger each workflow manually first:
```bash
gh workflow run guardrail-lint.yml
gh workflow run guardrail-drift.yml
```

---

### 3. Require Pull Request Reviews

Enable: **✅ Require a pull request before merging**

**Settings:**
- **Required approvals:** 1 (increase to 2 for critical paths)
- **✅ Dismiss stale pull request approvals when new commits are pushed**
- **✅ Require review from Code Owners**

**Code Owners enforcement:**
- Files matching `/02-qbusiness/guardrails/*` require approval from `@VaultSovereign/security`
- Files matching `/.github/workflows/*` require approval from `@VaultSovereign/ops`
- See [CODEOWNERS](../CODEOWNERS) for full matrix

---

### 4. Additional Protections

Enable the following for production-grade safety:

- **✅ Require conversation resolution before merging** — forces all review comments to be addressed
- **✅ Require signed commits** _(optional but recommended for fintech compliance)_
- **✅ Include administrators** — even admins must follow the rules (prevents accidental force-push)
- **✅ Restrict who can push to matching branches** — limit to CI/CD service accounts only

---

### 5. Force Push & Deletion

- **✅ Do not allow force pushes**
- **✅ Do not allow deletions**

---

## Verification

After configuring, test the protection:

1. **Create a test branch:**
   ```bash
   git checkout -b test/branch-protection
   ```

2. **Make a change to guardrails without review:**
   ```bash
   echo '{"test": true}' > 02-qbusiness/guardrails/topic-controls.json
   git add . && git commit -m "test: break guardrails"
   git push -u origin test/branch-protection
   ```

3. **Open a PR to `master`:**
   ```bash
   gh pr create --title "Test branch protection" --body "Should require security review"
   ```

4. **Expected behavior:**
   - PR cannot be merged until `Guardrail Lint` passes
   - PR requires approval from `@VaultSovereign/security` (due to CODEOWNERS)
   - Merging without approval is blocked

5. **Clean up:**
   ```bash
   gh pr close <PR-NUMBER>
   git checkout master
   git branch -D test/branch-protection
   git push origin --delete test/branch-protection
   ```

---

## Required GitHub Secrets

Ensure these secrets are configured for workflows to run:

| Secret Name | Purpose | Example Value |
|-------------|---------|---------------|
| `AWS_QB_OIDC_ROLE_ARN` | OIDC role for AWS auth | `arn:aws:iam::123456789012:role/GitHubActions-QBusiness` |
| `QB_APP_ID` | Q Business application ID | `a1b2c3d4-5678-90ab-cdef-EXAMPLE11111` |
| `QB_INDEX_ID` | Q Business index ID | `a1b2c3d4-5678-90ab-cdef-EXAMPLE22222` |
| `QB_DS_ID` | Data source ID | `a1b2c3d4-5678-90ab-cdef-EXAMPLE33333` |
| `QB_EXPORT_BUCKET` | S3 bucket for audit evidence | `vaultmesh-knowledge-base` |
| `ALERT_SNS_TOPIC_ARN` | SNS topic for SLO breach alerts | `arn:aws:sns:eu-west-1:123456789012:ops-alerts` |

---

## Maintenance

- **Review quarterly:** Ensure CODEOWNERS still reflects team structure
- **Audit annually:** Check that required checks are still valid and running
- **Update on org changes:** Add/remove teams as org structure evolves

---

**Last Updated:** October 19, 2025
**Maintained by:** VaultSovereign/ops
