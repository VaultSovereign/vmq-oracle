#!/usr/bin/env bash
# Deploy VMQ RUBEDO action Lambdas using direct CloudFormation + zipped code
set -euo pipefail

REGION=${AWS_REGION:-eu-west-1}
BUCKET=${EXPORT_BUCKET:-vaultmesh-knowledge-base}
STACK_NAME=vmq-actions-rubedo
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region "$REGION")

echo "→ Packaging Lambda functions for deployment..."

# Create build artifacts directory
mkdir -p .build
rm -rf .build/*

# Package each function with common layer
for fn in vmq-summarize-docs vmq-generate-faq vmq-draft-change-note \
          vmq-validate-schema vmq-create-jira-draft vmq-generate-compliance-pack; do
  echo "  → Packaging $fn"
  mkdir -p ".build/$fn"
  cp -r "$fn/"* ".build/$fn/"
  cp -r common ".build/$fn/"
  (cd ".build/$fn" && zip -q -r "../${fn}.zip" .)

  # Upload to S3
  aws s3 cp ".build/${fn}.zip" "s3://${BUCKET}/lambda-deploy/${fn}.zip" \
    --region "$REGION" --no-progress
done

echo "→ Creating/updating CloudFormation stack..."

# Convert SAM template to pure CloudFormation by replacing CodeUri with S3 references
cat > .build/template-cfn.yaml <<EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: VMQ • Six green-tier action Lambdas (RUBEDO), Python 3.12

Parameters:
  ExportBucket:
    Type: String
    Default: ${BUCKET}
  OpaUrl:
    Type: String
    Default: ""
    Description: Optional OPA endpoint URL

Resources:
  # Execution role for all functions
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: vmq-actions-rubedo-role
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        - arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess
      Policies:
        - PolicyName: vmq-actions-policy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Sid: ReadPersonasAndCatalog
                Effect: Allow
                Action:
                  - s3:GetObject
                Resource:
                  - !Sub 'arn:aws:s3:::\${ExportBucket}/personas/*'
                  - !Sub 'arn:aws:s3:::\${ExportBucket}/actions/*'
              - Sid: PublishActionMetrics
                Effect: Allow
                Action:
                  - cloudwatch:PutMetricData
                Resource: '*'
                Condition:
                  StringEquals:
                    'cloudwatch:namespace': 'VaultMesh/QBusinessActions'

  # Log groups
  LogGroupSummarize:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /aws/lambda/vmq-summarize-docs
      RetentionInDays: 14
  LogGroupFaq:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /aws/lambda/vmq-generate-faq
      RetentionInDays: 14
  LogGroupChangeNote:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /aws/lambda/vmq-draft-change-note
      RetentionInDays: 14
  LogGroupValidateSchema:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /aws/lambda/vmq-validate-schema
      RetentionInDays: 14
  LogGroupJiraDraft:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /aws/lambda/vmq-create-jira-draft
      RetentionInDays: 14
  LogGroupCompliancePack:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: /aws/lambda/vmq-generate-compliance-pack
      RetentionInDays: 14

  # Functions
  FnSummarize:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: vmq-summarize-docs
      Runtime: python3.12
      Handler: handler.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 10
      MemorySize: 256
      TracingConfig:
        Mode: Active
      Environment:
        Variables:
          LOG_LEVEL: INFO
          EXPORT_BUCKET: !Ref ExportBucket
          OPA_URL: !Ref OpaUrl
      Code:
        S3Bucket: !Ref ExportBucket
        S3Key: lambda-deploy/vmq-summarize-docs.zip

  FnFaq:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: vmq-generate-faq
      Runtime: python3.12
      Handler: handler.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 10
      MemorySize: 256
      TracingConfig:
        Mode: Active
      Environment:
        Variables:
          LOG_LEVEL: INFO
          EXPORT_BUCKET: !Ref ExportBucket
          OPA_URL: !Ref OpaUrl
      Code:
        S3Bucket: !Ref ExportBucket
        S3Key: lambda-deploy/vmq-generate-faq.zip

  FnChangeNote:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: vmq-draft-change-note
      Runtime: python3.12
      Handler: handler.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 10
      MemorySize: 256
      TracingConfig:
        Mode: Active
      Environment:
        Variables:
          LOG_LEVEL: INFO
          EXPORT_BUCKET: !Ref ExportBucket
          OPA_URL: !Ref OpaUrl
      Code:
        S3Bucket: !Ref ExportBucket
        S3Key: lambda-deploy/vmq-draft-change-note.zip

  FnValidateSchema:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: vmq-validate-schema
      Runtime: python3.12
      Handler: handler.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 10
      MemorySize: 256
      TracingConfig:
        Mode: Active
      Environment:
        Variables:
          LOG_LEVEL: INFO
          EXPORT_BUCKET: !Ref ExportBucket
          OPA_URL: !Ref OpaUrl
      Code:
        S3Bucket: !Ref ExportBucket
        S3Key: lambda-deploy/vmq-validate-schema.zip

  FnJiraDraft:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: vmq-create-jira-draft
      Runtime: python3.12
      Handler: handler.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 10
      MemorySize: 256
      TracingConfig:
        Mode: Active
      Environment:
        Variables:
          LOG_LEVEL: INFO
          EXPORT_BUCKET: !Ref ExportBucket
          OPA_URL: !Ref OpaUrl
      Code:
        S3Bucket: !Ref ExportBucket
        S3Key: lambda-deploy/vmq-create-jira-draft.zip

  FnCompliancePack:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: vmq-generate-compliance-pack
      Runtime: python3.12
      Handler: handler.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 10
      MemorySize: 256
      TracingConfig:
        Mode: Active
      Environment:
        Variables:
          LOG_LEVEL: INFO
          EXPORT_BUCKET: !Ref ExportBucket
          OPA_URL: !Ref OpaUrl
      Code:
        S3Bucket: !Ref ExportBucket
        S3Key: lambda-deploy/vmq-generate-compliance-pack.zip

Outputs:
  SummarizeFnArn:
    Value: !GetAtt FnSummarize.Arn
  FaqFnArn:
    Value: !GetAtt FnFaq.Arn
  ChangeNoteFnArn:
    Value: !GetAtt FnChangeNote.Arn
  ValidateSchemaFnArn:
    Value: !GetAtt FnValidateSchema.Arn
  JiraDraftFnArn:
    Value: !GetAtt FnJiraDraft.Arn
  CompliancePackFnArn:
    Value: !GetAtt FnCompliancePack.Arn
EOF

# Deploy stack
aws cloudformation deploy \
  --template-file .build/template-cfn.yaml \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    ExportBucket="$BUCKET" \
    OpaUrl="" \
  --region "$REGION" \
  --no-fail-on-empty-changeset

echo "✓ Stack deployed: $STACK_NAME"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs' \
  --output table
