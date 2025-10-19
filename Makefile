SHELL := /usr/bin/env bash
.SHELLFLAGS := -eo pipefail -c

REGION ?= eu-west-1

.PHONY: validate bootstrap roles app index retriever s3 sync wait-sync guardrails web weburl web-url bundle github-oidc-role pipeline-aws-native s3-prefix-metrics s3-lifecycle-90d

bootstrap:
	@./01-foundation/iam/roles/create-roles.sh

roles:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 ./01-foundation/iam/roles/create-roles.sh

app:
	@./02-qbusiness/app/create-application.sh | tee .app.out
	@awk -F= '/APP_ID/{print $$0}' .app.out > .env

index:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 APP_ID=$${APP_ID:?APP_ID missing}; \
	 ./02-qbusiness/index/create-index.sh $$APP_ID | tee .index.out
	@awk -F= '/INDEX_ID/{print $$0}' .index.out >> .env

retriever:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 APP_ID=$${APP_ID:?}; INDEX_ID=$$(awk -F= '/INDEX_ID/{print $$2}' .index.out); \
	 ./02-qbusiness/index/create-retriever.sh $$APP_ID $$INDEX_ID | tee .retriever.out; \
	 awk -F= '/RETRIEVER_ID/{print $$0}' .retriever.out >> .env

s3:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 ./02-qbusiness/datasources/create-s3-ds.sh | tee .s3ds.out; \
	 awk -F= '/DS_ID/{print $$0}' .s3ds.out >> .env

sync:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 ./02-qbusiness/datasources/start-sync.sh

wait-sync:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 ./02-qbusiness/datasources/wait-sync.sh

web:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 APP_ID=$${APP_ID:?}; ./02-qbusiness/web/create-web-experience.sh $$APP_ID | tee .web.out
	@awk -F= '/WEB_EXPERIENCE_ID/{print $$0}' .web.out >> .env

weburl web-url:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 APP_ID=$${APP_ID:?}; \
	 ./02-qbusiness/web/get-web-url.sh $$APP_ID

# Apply guardrails from YAML (preferred) or JSON
guardrails:
	@which yq >/dev/null 2>&1 || { echo "yq is required (https://mikefarah.gitbook.io/yq/)"; exit 1; }
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 yq -o=json 02-qbusiness/guardrails/topic-controls.yaml > /tmp/qb-guardrails.json; \
	 aws qbusiness update-chat-controls-configuration \
	   --region "$$REGION" \
	   --application-id "$$APP_ID" \
	   --cli-input-json file:///tmp/qb-guardrails.json; \
	 echo "✅ Guardrails applied to $$APP_ID"

guardrails-json:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 aws qbusiness update-chat-controls-configuration \
	   --region "$$REGION" \
	   --application-id "$$APP_ID" \
	   --cli-input-json file://02-qbusiness/guardrails/topic-controls.json; \
	 echo "✅ Guardrails applied to $$APP_ID"

# Print the Web Experience URL (create one if missing with 'make web' first)
publish-url:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 if [ -z "$$WEB_EXPERIENCE_ID" ]; then \
	   echo "WEB_EXPERIENCE_ID not set. Create in console or run 'make web'."; exit 1; \
	 fi; \
	 aws qbusiness get-web-experience \
	   --region "$$REGION" \
	   --application-id "$$APP_ID" \
	   --web-experience-id "$$WEB_EXPERIENCE_ID" \
	   --query defaultEndpoint --output text

publish-url-sso:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 aws qbusiness get-web-experience \
	   --region "$$REGION" --application-id "$$APP_ID" \
	   --web-experience-id "$$WEB_EXPERIENCE_ID" \
	   --query defaultEndpoint --output text

sovereign-sync:
	@./scripts/sovereign-sync.sh

validate:
	@aws --version >/dev/null
	@aws sts get-caller-identity --query Account --output text
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 aws s3 ls "s3://$$BUCKET_NAME" >/dev/null

bundle:
	@zip -rq vaultmesh-qb-bundle.zip . -x "*.git*" "*.DS_Store"
	@echo "Created ./vaultmesh-qb-bundle.zip"

github-oidc-role:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 : \
	 ; BUCKET_NAME=$${BUCKET_NAME:?Set BUCKET_NAME in .env}; \
	 : \
	 ; GITHUB_ORG=$${GITHUB_ORG:?export GITHUB_ORG in env}; \
	 GITHUB_REPO=$${GITHUB_REPO:?export GITHUB_REPO in env}; \
	 GITHUB_BRANCH=$${GITHUB_BRANCH:-main}; \
	 REGION=$${REGION:-eu-west-1}; \
	 ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text); \
	 BUCKET_NAME="$$BUCKET_NAME" GITHUB_ORG="$$GITHUB_ORG" GITHUB_REPO="$$GITHUB_REPO" GITHUB_BRANCH="$$GITHUB_BRANCH" REGION="$$REGION" ACCOUNT_ID="$$ACCOUNT_ID" \
	 ./01-foundation/iam/roles/create-github-oidc-role.sh

pipeline-aws-native:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 REPO_NAME=$${PIPELINE_REPO_NAME:-vmq-docs}; \
	 BRANCH_NAME=$${PIPELINE_BRANCH_NAME:-main}; \
	 REGION=$${REGION:-eu-west-1}; \
	 echo "Deploying AWS-native pipeline (CodeCommit/CodeBuild/CodePipeline)..."; \
	 aws cloudformation deploy \
	   --region "$$REGION" \
	   --stack-name qbusiness-pipeline \
	   --template-file 02-qbusiness/pipeline/qbusiness-pipeline.yaml \
	   --capabilities CAPABILITY_NAMED_IAM \
	   --parameter-overrides \
	     RepoName="$$REPO_NAME" \
	     BranchName="$$BRANCH_NAME" \
	     ExportBucket="$$BUCKET_NAME" \
	     QbAppId="$$APP_ID" \
	     QbIndexId="$$INDEX_ID" \
	     QbDataSourceId="$$DS_ID" \
	     ApplyGuardrailsByCommitMsg=false; \
	 echo "--- Outputs ---"; \
	 aws cloudformation describe-stacks \
	   --region "$$REGION" --stack-name qbusiness-pipeline \
	   --query 'Stacks[0].Outputs' --output table

s3-versioning-on:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 aws s3api put-bucket-versioning --bucket "$$BUCKET_NAME" --versioning-configuration Status=Enabled; \
	 echo "Enabled versioning on bucket $$BUCKET_NAME"

pipeline-alarms:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 PIPELINE_NAME=$${AWS_NATIVE_PIPELINE_NAME:?export AWS_NATIVE_PIPELINE_NAME (pipeline name)}; \
	 EMAIL=$${ALARM_EMAIL:?export ALARM_EMAIL to receive notifications}; \
	 REGION=$${REGION:-eu-west-1}; \
	 aws cloudformation deploy \
	   --region "$$REGION" \
	   --stack-name qbusiness-alarms \
	   --template-file 02-qbusiness/monitoring/qbusiness-alarms.yaml \
	   --capabilities CAPABILITY_NAMED_IAM \
	   --parameter-overrides PipelineName="$$PIPELINE_NAME" TopicEmail="$$EMAIL"; \
	 aws cloudformation describe-stacks --region "$$REGION" --stack-name qbusiness-alarms \
	   --query 'Stacks[0].Outputs' --output table

kms-deploy:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 REGION=$${REGION:-eu-west-1}; \
	 : $${ROLE_ARN:?export ROLE_ARN (QBusiness DS role arn) in .env}; \
	 : $${AWS_QB_OIDC_ROLE_ARN:?export AWS_QB_OIDC_ROLE_ARN (GitHub OIDC role arn)}; \
	 aws cloudformation deploy \
	   --region "$$REGION" \
	   --stack-name qbusiness-kms-bucket \
	   --template-file 02-qbusiness/security/kms-bucket.yaml \
	   --parameter-overrides \
	     BucketName="$$BUCKET_NAME" \
	     CiRoleArn="$$AWS_QB_OIDC_ROLE_ARN" \
	     QbDsRoleArn="$$ROLE_ARN"; \
	 aws cloudformation describe-stacks --region "$$REGION" --stack-name qbusiness-kms-bucket \
	   --query 'Stacks[0].Outputs' --output table

nosync-alarm:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 : $${APP_ID:?}; : $${INDEX_ID:?}; : $${DS_ID:?}; \
	 REGION=$${REGION:-eu-west-1}; \
	 TOPIC_ARN=$${SNS_TOPIC_ARN:?export SNS_TOPIC_ARN from alarms output}; \
	 aws cloudformation deploy \
	   --region "$$REGION" \
	   --stack-name qbusiness-nosync \
	   --template-file 02-qbusiness/monitoring/qbusiness-nosync-checker.yaml \
	   --capabilities CAPABILITY_NAMED_IAM \
	   --parameter-overrides AppId="$$APP_ID" IndexId="$$INDEX_ID" DataSourceId="$$DS_ID" TopicArn="$$TOPIC_ARN" MaxHours=24; \
	 aws cloudformation describe-stacks --region "$$REGION" --stack-name qbusiness-nosync \
	   --query 'Stacks[0].Outputs' --output table

dashboard-deploy:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 : $${AWS_NATIVE_PIPELINE_NAME:?export AWS_NATIVE_PIPELINE_NAME}; \
	 REGION=$${REGION:-eu-west-1}; \
	 DNAME=$${DASHBOARD_NAME:-VaultMesh-QBusiness}; \
	 TMP=$$(mktemp); \
	 sed -e "s/__REGION__/$$REGION/g" \
	     -e "s/__PIPELINE_NAME__/$$AWS_NATIVE_PIPELINE_NAME/g" \
	     -e "s/__APP_ID__/$$APP_ID/g" \
	     02-qbusiness/monitoring/qbusiness-dashboard.json.tmpl > $$TMP; \
	 aws cloudwatch put-dashboard --region "$$REGION" --dashboard-name "$$DNAME" --dashboard-body file://$$TMP; \
	 rm -f $$TMP; \
	 echo "✅ Deployed dashboard '$$DNAME' in $$REGION"

s3-prefix-metrics:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 REGION=$${REGION:-eu-west-1}; \
	 PREF=$${S3_PREFIXES_JSON:-'["","_staging/"]'}; \
	 aws cloudformation deploy \
	   --region "$$REGION" \
	   --stack-name qbusiness-s3-prefix-metrics \
	   --template-file 02-qbusiness/monitoring/s3-prefix-metrics.yaml \
	   --capabilities CAPABILITY_NAMED_IAM \
	   --parameter-overrides BucketName="$$BUCKET_NAME" PrefixesJson="$$PREF"; \
	 aws cloudformation describe-stacks \
	   --region "$$REGION" --stack-name qbusiness-s3-prefix-metrics \
	   --query 'Stacks[0].Outputs' --output table

s3-lifecycle-90d:
	@[ -f .env ] && set -a && . ./.env && set +a; \
	 aws s3api put-bucket-lifecycle-configuration \
	   --bucket "$$BUCKET_NAME" \
	   --lifecycle-configuration file://02-qbusiness/security/s3-lifecycle-90d.json; \
	 echo "✅ Applied 90-day lifecycle to $$BUCKET_NAME for ci/, _staging/dr/, audit/promotions/"
