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

hdr "Bedrock models (Claude / Nova)"
Q aws bedrock list-foundation-models \
  --query "modelSummaries[?contains(modelId,'claude')||contains(modelId,'nova')].modelId" --output text
echo "--- inference profiles"
Q aws bedrock list-inference-profiles \
  --query "inferenceProfileSummaries[?contains(inferenceProfileId,'claude')||contains(inferenceProfileId,'nova')].inferenceProfileId" --output text

hdr "IAM roles matching *agentcore*"
Q aws iam list-roles --query "Roles[?contains(to_string(RoleName),'gentcore')||contains(to_string(RoleName),'AgentCore')].[RoleName,Arn]" --output table

exit 0
