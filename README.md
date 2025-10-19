VaultMesh × Amazon Q Business Bundle (eu-west-1)

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

