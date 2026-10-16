#!/usr/bin/env bash
# Read-only recon of the GameDay account. No set -e: every section runs regardless.
hdr() { printf '\n===== %s =====\n' "$*"; }
Q() { "$@" 2>&1 || echo "(failed: $*)"; }

hdr "Identity / region"
Q aws sts get-caller-identity --output table
REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null)}}
echo "Region: ${REGION:-<unset>}"

hdr "AgentCore runtimes"
Q aws bedrock-agentcore-control list-agent-runtimes \
  --query 'agentRuntimes[].[agentRuntimeName,agentRuntimeId,status]' --output table

hdr "AgentCore gateways + targets"
GWS=$(aws bedrock-agentcore-control list-gateways --query 'items[].gatewayId' --output text 2>/dev/null)
Q aws bedrock-agentcore-control list-gateways --query 'items[].[name,gatewayId,status]' --output table
for g in $GWS; do
  echo "--- targets of $g"
  Q aws bedrock-agentcore-control list-gateway-targets --gateway-identifier "$g" \
    --query 'items[].[name,targetId,status]' --output table
done

hdr "Lambda functions"
Q aws lambda list-functions --query 'Functions[].[FunctionName,Runtime,Architectures[0]]' --output table

hdr "DynamoDB tables"
Q aws dynamodb list-tables --output table

hdr "Cognito user pools"
POOLS=$(aws cognito-idp list-user-pools --max-results 60 --query 'UserPools[].Id' --output text 2>/dev/null)
Q aws cognito-idp list-user-pools --max-results 60 --query 'UserPools[].[Name,Id]' --output table
for p in $POOLS; do
  echo "--- app clients of $p"
  Q aws cognito-idp list-user-pool-clients --user-pool-id "$p" --query 'UserPoolClients[].[ClientName,ClientId]' --output table
done

hdr "Bedrock models (Claude / Nova / Titan)"
Q aws bedrock list-foundation-models \
  --query "modelSummaries[?contains(modelId,'claude')||contains(modelId,'nova')||contains(modelId,'titan')].modelId" --output text
echo "--- inference profiles"
Q aws bedrock list-inference-profiles \
  --query "inferenceProfileSummaries[?contains(inferenceProfileId,'claude')||contains(inferenceProfileId,'nova')||contains(inferenceProfileId,'titan')].inferenceProfileId" --output text

hdr "Bedrock Knowledge Bases"
KBS=$(aws bedrock-agent list-knowledge-bases --query 'knowledgeBaseSummaries[].knowledgeBaseId' --output text 2>/dev/null)
Q aws bedrock-agent list-knowledge-bases --query 'knowledgeBaseSummaries[].[name,knowledgeBaseId,status]' --output table
for k in $KBS; do
  echo "--- data sources of $k"
  Q aws bedrock-agent list-data-sources --knowledge-base-id "$k" --query 'dataSourceSummaries[].[name,dataSourceId,status]' --output table
done

hdr "Bedrock Guardrails"
Q aws bedrock list-guardrails --query 'guardrails[].[name,id,version,status]' --output table

hdr "S3 buckets"
Q aws s3api list-buckets --query 'Buckets[].Name' --output text

hdr "OpenSearch (domains + serverless collections)"
Q aws opensearch list-domain-names --query 'DomainNames[].DomainName' --output text
Q aws opensearchserverless list-collections --query 'collectionSummaries[].[name,id,status]' --output table

hdr "EventBridge (buses + rules on default bus)"
Q aws events list-event-buses --query 'EventBuses[].Name' --output text
Q aws events list-rules --query 'Rules[].[Name,State,ScheduleExpression]' --output table

hdr "EC2 instances"
Q aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`]|[0].Value]' --output table

hdr "ECR repositories"
Q aws ecr describe-repositories --query 'repositories[].repositoryName' --output text

hdr "Amazon Location Service"
Q aws location list-maps --query 'Entries[].MapName' --output text
Q aws location list-place-indexes --query 'Entries[].IndexName' --output text
Q aws location list-route-calculators --query 'Entries[].CalculatorName' --output text

hdr "Step Functions"
Q aws stepfunctions list-state-machines --query 'stateMachines[].name' --output text

hdr "IAM roles matching *agentcore*"
Q aws iam list-roles --query "Roles[?contains(to_string(RoleName),'gentcore')||contains(to_string(RoleName),'AgentCore')].[RoleName,Arn]" --output table

exit 0
