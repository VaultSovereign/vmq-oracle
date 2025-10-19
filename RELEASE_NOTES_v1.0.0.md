# VaultMesh Q Business — v1.0.0 “Citrinitas”

**Date:** 2025-10-19  
**Tag:** v1.0.0

## Highlight
Sovereign observability lattice sealed: dual-lane CI/DR publishing with stage-and-promote, KMS-sealed exports, guardrailed SSO Web Experience, and full dashboard telemetry.

## What’s inside
- **SSO Application:** APP_ID=062f… (ACTIVE), guarded topics (2), minimal blocked phrases
- **Index & Retriever:** Native index (ACTIVE), 7 seed docs, fast re-ingest pipelines
- **Dual Lane Publishing:**
  - **Primary:** GitHub OIDC → S3 root → StartDataSourceSyncJob → SUCCEEDED wait → artifacts
  - **DR:** CodeCommit/Build/Pipeline → **_staging/** → parity → **promote** → audit record
- **Security:** SSE-KMS (default bucket encryption), deny non-TLS/non-KMS PUT, scoped IAM
- **Observability:** 
  - CloudWatch dashboard: SyncFailed, NoSync, CodePipeline health
  - S3 daily size/object count + 15-min prefix metrics (root vs `_staging/`)
  - 24h No-Sync alarm (SNS), SyncFailed metric on errors
- **Audit:** Promotion record at `s3://<bucket>/audit/promotions/promotion-<ts>.json`

## Ops
- **Dash deploy:** `make dashboard-deploy`  
- **Docs sync:** `bash scripts/sovereign-sync-docs.sh docs/ && bash scripts/sovereign-verify-ingest.sh`  
- **DR drill:** GitHub → Actions → “DR Monthly” (parity+promote)

## Known limits
- Q guardrails: **max 2 topics**, concise phrase lists
- S3 daily metrics update cadenced; prefix metrics real-time via Lambda

## Next (Rubedo)
- Connector A (Confluence) → B (GitHub) → C (Drive) → D (Slack)
- DR quarterly tabletop
- Add 20–30 concise scrolls and synonyms
