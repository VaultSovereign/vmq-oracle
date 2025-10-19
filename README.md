VaultMesh × Amazon Q Business Bundle (eu-west-1)

[![Docs → S3 → Q Sync](https://github.com/VaultSovereign/vmq-oracle/actions/workflows/qbusiness-sync.yml/badge.svg)](../../actions/workflows/qbusiness-sync.yml)
[![DR Monthly Parity](https://github.com/VaultSovereign/vmq-oracle/actions/workflows/dr-monthly.yml/badge.svg)](../../actions/workflows/dr-monthly.yml)
![Tag](https://img.shields.io/github/v/tag/VaultSovereign/vmq-oracle?label=release)

> 🟩 **RUBEDO SSO CUTOVER COMPLETE** — October 19, 2025  
> **Status:** PRODUCTION GREEN  
> **Identity:** AWS IAM Identity Center (SSO)  
> **Web Experience:** https://zerkno58.chat.qbusiness.eu-west-1.on.aws/  
> 
> → See [`RUBEDO-CUTOVER-CARD.md`](RUBEDO-CUTOVER-CARD.md) for operator runbook  
> → Pin [`SLACK-PIN-RUBEDO-CUTOVER.md`](SLACK-PIN-RUBEDO-CUTOVER.md) in #vaultmesh-ops

What this provides
- Application → Index → Retriever → Data sources → Guardrails → Web experience
- IAM admin policy and datasource role (trusts qbusiness.amazonaws.com)
- Starter Q Apps JSONs
- Makefile for one-command provisioning

Quick start
1) Configure AWS CLI for the correct account in eu-west-1.
2) Copy env template: `cp .env.example .env` and fill values.
3) Run in order:
   - `make app`
   - `make index && make retriever`
   - `make roles` (after APP_ID/INDEX_ID exist)
   - Edit `02-qbusiness/datasources/s3-ds.json` bucket name
   - `make s3 && make sync`
   - `make guardrails`
   - `make web && make web-url`

Key paths
- IAM: `01-foundation/iam/policies/*`, `01-foundation/iam/roles/create-roles.sh`
- Q Business: `02-qbusiness/*`
- Migration: `04-migration/*`

Notes
- Keep datasource connector JSONs aligned with AWS docs before production.
- All scripts default to eu-west-1; override with `REGION`.
- After editing guardrails: run `make guardrails-verify` locally, then open a PR (Guardrail Lint must pass).

## Service SLOs & Observability

- **Sync availability SLO:** 99.5% monthly (SyncFailed alarms sustain at 0).
- **Time-to-knowledge (TTK):** < 10 seconds p95 from query to answer in the Web Experience.
- **Alarms:** “NoSync > 24h” and “SyncFailed > 0” route to `#ops-escalations` on-call rotation.
- **Dashboard:** CloudWatch “VaultMesh Sovereign” view shows SyncFailed, NoSync, CodePipeline health, and prefix metrics for `root/` vs `_staging/`. Deploy updates with `make dashboard-deploy`.

## Ops Snapshot

- **CloudWatch dashboard:** [`VaultMesh-Sovereign`](https://console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=VaultMesh-Sovereign)
- **DR monthly workflow:** [`dr-monthly.yml`](../../actions/workflows/dr-monthly.yml)
- **No-sync daily workflow:** [`no-sync-daily.yml`](../../actions/workflows/no-sync-daily.yml)
- **Guardrail drift workflow:** [`guardrail-drift.yml`](../../actions/workflows/guardrail-drift.yml)
- **Guardrail lint:** [`guardrail-lint.yml`](../../actions/workflows/guardrail-lint.yml)
- **Guardrails JSON:** [`02-qbusiness/guardrails/topic-controls.json`](02-qbusiness/guardrails/topic-controls.json)
- **Knowledge bucket:** `s3://vaultmesh-knowledge-base`

