# Project Feedback Template

## Feedback Submission Form

### 1. Feedback Category
- [ ] Feature Request
- [ ] Bug Report
- [ ] Documentation Gap
- [ ] Process Improvement
- [ ] Security/Compliance Concern
- [ ] Performance Issue
- [ ] User Experience

### 2. Module/Domain
- [ ] Foundation (IAM, roles, policies, SSO)
- [ ] Q Business (app, index, datasources, guardrails)
- [ ] Lambdas (document processing, functions)
- [ ] Web (Web Experience, UI integration)
- [ ] Monitoring (CloudWatch, dashboards, alarms)
- [ ] Observability/Ops
- [ ] Migration

### 3. Severity Level
- [ ] Critical (blocks deployment/functionality)
- [ ] High (impacts core workflows)
- [ ] Medium (affects efficiency/clarity)
- [ ] Low (nice-to-have improvement)

---

## Feedback Details

### Title
*Brief, descriptive title (will become commit subject)*

```
<type>(<scope>): <short description>
```

**Example:** `feat(qbusiness): add real-time sync status dashboard`

---

### Description
*Detailed explanation of the feedback*

**What is the current state?**
- 

**What should change?**
- 

**Why is this important?**
- 

---

### Affected Components
*List specific files, scripts, or modules*

- `02-qbusiness/monitoring/qbusiness-dashboard.json.tmpl`
- `03-lambdas/vmq-summarize-docs/index.py`
- `Makefile`

---

### Proposed Solution (Optional)
*If you have a specific implementation in mind*

```bash
# Example: command or code snippet
make qbusiness-monitor
```

---

### Testing Recommendations
- [ ] Unit tests included
- [ ] Manual testing completed
- [ ] CloudWatch validation confirmed
- [ ] Deployed to sandbox first

---

### Documentation Impact
- [ ] Runbook update needed
- [ ] AGENTS.md clarification required
- [ ] New troubleshooting section
- [ ] No documentation changes

---

### Links & References
- Related Issue: #
- Related PR: #
- Runbook: docs/
- Slack Thread: [link]

---

### Conventional Commit Preview

**Type:** `feat` | `fix` | `docs` | `refactor` | `test` | `chore`

**Scope:** foundation | qbusiness | lambdas | web | monitoring

**Subject:**
```
<type>(<scope>): <imperative verb> <description>
```

**Body (optional):**
```
- Bullet point 1
- Bullet point 2
- Closes/Related-to: #issue
```

---

## Submission Checklist

- [ ] Category and severity selected
- [ ] Module clearly identified
- [ ] Description is specific and actionable
- [ ] Affected components listed
- [ ] Testing strategy outlined
- [ ] Conventional commit format ready
- [ ] No sensitive data (.env, credentials) included
- [ ] Ready for PR review

---

## Quick Reference: Commit Examples by Domain

### Foundation Feedback
```
feat(foundation): add eu-central-1 region support to IAM policies

- Extend iam/policies/*.json.tmpl with secondary region
- Update roles/create-roles.sh to handle multi-region deployment
- Add region override via REGION environment variable

Closes #28
```

### Q Business Feedback
```
fix(qbusiness): resolve datasource sync lag on Confluence connector

- Increase sync frequency from 6h to 1h for critical collections
- Add CloudWatch alarm for datasource lag > 30min
- Update monitoring/qbusiness-alarms.yaml with new metric

Related-to: SLACK-PIN-RUBEDO-CUTOVER.md sync requirements
```

### Lambdas Feedback
```
docs(lambdas): clarify test event structure for vmq-summarize-docs

- Add representative test fixtures in test-events.json
- Document required IAM permissions in README.md
- Add CloudWatch log validation steps to testing checklist

No code changes.
```

### Monitoring Feedback
```
feat(monitoring): add per-datasource ingestion health dashboard

- Extend qbusiness-dashboard.json.tmpl with datasource metrics
- Create s3-prefix-metrics.yaml for knowledge bucket monitoring
- Include sync latency, object count, and ingestion rate panels

Closes #45
```