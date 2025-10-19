# VaultMesh Q Business Agent Guidelines

## Project Overview
VaultMesh × Amazon Q Business Bundle provides intelligent knowledge management with sub-10 second query response times and 99.5% sync availability SLO. Transforms static documentation into searchable knowledge base with automated provisioning and operational monitoring.

## Project Structure & Module Organization
- `01-foundation/` seeds IAM roles and policies (`iam/policies/*.json.tmpl`, `roles/create-roles.sh`) for eu-west-1 by default.
- `02-qbusiness/` holds app, index, datasource scripts, guardrails (YAML→JSON), personas, pipeline, monitoring templates, and web helpers; generated IDs live in `.env`.
- `03-lambdas/` contains document processing Lambdas with shared `common/` utilities and `template-sam.yaml`; `03-observability/` and `04-migration/` capture ops notes and migration checklists.
- Knowledge bucket: `s3://vaultmesh-knowledge-base` with automated sync workflows.

## Build, Test, and Development Commands
- `make app`, `make index`, `make retriever`, `make roles`, `make s3`, `make sync` provision Q Business resources—execute in that order after populating `.env`.
- `make guardrails` applies YAML guardrails via `yq`; `make web` plus `make web-url` publishes and retrieves the Web Experience endpoint—run `make validate` first to confirm AWS identity.
- Lambda workflows: `make lambdas-build`→SAM build, `make lambdas-deploy`→SAM deploy, `make lambdas-test`→invoke `vmq-summarize-docs` with `03-lambdas/test-events.json`.

## Coding Style & Naming Conventions
- Bash scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`; prefer `${VAR:?}` guards, long-form CLI flags, and `envsubst` for template rendering.
- Python Lambdas target 3.12, keep 4-space indentation, lean on stdlib + `common/vmq_common.py`, and return Gateway-compatible dicts through `ok`/`err`.
- JSON/YAML templates use double quotes, two-space indents, and kebab-case action IDs (`summarize-docs`, `generate-faq`); keep AWS ARNs and account IDs parameterized.

## Testing Guidelines
- Extend `03-lambdas/test-events.json` with representative fixtures; run `aws lambda invoke` or SAM local tests to validate deterministic stub outputs.
- After datasource changes, run `make wait-sync` and inspect CloudWatch dashboards from `02-qbusiness/monitoring/` to confirm ingestion health.
- Note coverage expectations in PRs (tests run, manual checks) and log outstanding gaps in the relevant runbook when automation is pending.

## Commit & Pull Request Guidelines
- Follow the conventional commit style found here (`feat:`, `docs:`) with imperative summaries, e.g., `feat: add prefix metrics stack`.
- PRs must call out touched domains (foundation/qbusiness/lambdas), link issues, list executed commands/tests, and attach URLs or screenshots when guardrails or web UX change.
- Update runbooks or docs when behavior shifts and note those updates explicitly in the PR description.

## Security & Configuration Tips
- Never commit `.env`; contributors should export `REGION`, `BUCKET_NAME`, role ARNs, and optional `OPA_URL` locally before running scripts.
- Validate IAM and guardrail edits in a sandbox account first; scripts default to eu-west-1 unless `REGION` is overridden.
- Keep Lambda logs structured via `vmq_common` and rely on OPA gating (`OPA_URL`) or the static GREEN map instead of exposing PII.
