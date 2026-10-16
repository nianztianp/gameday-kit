# GameDay Day-Of Instructions

Speed mode. No coaching, no tutorials, no long explanations. Act, report in a few lines. Event text is in Japanese: read it in Japanese, reply to me in the language I use.

## Challenges

1. **Nova Nexus MCP (1-2)**: connect an MCP server to an agent; build multiple agents.
2. **失われた色の伝説**: AgentCore Gateway + Identity, Lambda tools; solve puzzles by talking to the agent.
3. **暗号解読ユニコーン**: multi-agent on AgentCore.
4. **ピザ泥棒**: Strands + A2A multi-agent on AgentCore Runtime + Amazon Location Service.

## Rules

1. Run `./recon.sh` first. Read its output before doing anything.
2. Read the challenge text fully before coding. Note exact names, required outputs, and scoring hints.
3. REUSE pre-provisioned resources (runtimes, gateways, roles, tables, Lambdas, Cognito pools). Do not recreate what exists.
4. The lab account is disposable: create/update/delete AWS resources (IAM roles included) directly, no need to ask. Still prefer reusing what exists.
5. AgentCore Runtime containers are **arm64**. Build with `--platform linux/arm64` (or use the starter toolkit's CodeBuild path).
6. Verify AgentCore / Strands / A2A APIs via the docs MCP servers (strands, bedrock-agentcore-mcp-server, aws-documentation), not memory. Signatures change.
7. Tool descriptions and system prompts are scoring levers. Word them precisely: when to call, what it takes, what it returns, what not to use it for.

## Tooling

- MCP: `strands`, `aws-documentation` for API lookups. `bedrock-agentcore-mcp-server` has docs tools plus runtime/gateway/identity/memory/browser/code-interpreter tools: use them to create, invoke and inspect AgentCore resources directly. `aws-mcp` (from `aws configure agent-toolkit`) runs any AWS API call with the lab credentials.
- AWS skills worth loading: `amazon-bedrock` (AgentCore Runtime/Gateway/Identity, model IDs), `aws-iam` (execution/outbound roles, trust policies), `aws-serverless` (Lambda tools), `aws-auth` (Cognito JWT for Gateway inbound auth), `aws-observability` (CloudWatch logs/traces), `aws-sdk-python-usage` (boto3), `aws-containers` (ECR, arm64 images).
- This file is also `AGENTS.md` (symlink) for Codex.

## Likely services in the event

Event scope: AgentCore, Strands, MCP, Bedrock Guardrails + Knowledge Bases; models Nova Canvas, Nova Pro, Claude Haiku/Sonnet/Opus, Titan Text Embeddings V2; plus DynamoDB, EC2, EventBridge, OpenSearch, S3, serverless.

- Model IDs: take the exact ID/inference-profile from recon output (`us.`/`global.` prefixes); do not guess versions.
- Nova Canvas (image) and Titan Embeddings V2 use InvokeModel, not Converse. Check region availability and request body via docs.
- Knowledge Base: data source (S3) must be synced (ingestion job) before queries return anything. Embedding model and vector index dimension must match (Titan V2 supports 256/512/1024). Query via `bedrock-agent-runtime` Retrieve / RetrieveAndGenerate.
- Guardrails: attach by ID + version to the model call (Strands `BedrockModel(guardrail_id=..., guardrail_version=...)`; verify in docs). Check which topic/word/PII filters block your test input.
- OpenSearch Serverless: needs data access policy for your principal, or queries return 403.
- Extra skills: `aws-database` (DynamoDB/OpenSearch choices), `aws-storage` (S3), `aws-messaging-and-streaming` (EventBridge), `aws-compute` (EC2), `aws-serverless`.

## Debug checklist: agent does not call a tool

Go in order:

1. System prompt: does it tell the agent when/why to use the tool?
2. Tool description: clear trigger conditions and examples?
3. Input schema: types, required fields, enum values, parameter descriptions.
4. Model access / region: model enabled in this region? Correct model/inference-profile ID?
5. Gateway target / tool listing: target created and READY? Does `tools/list` show the tool (names are prefixed with the target name)?
6. IAM: which principal is failing?
   - Runtime execution role (invoking Bedrock, Gateway, ECR, logs)
   - Gateway outbound role / credential provider (Gateway to Lambda/target)
   - Inbound auth: JWT (Cognito client, audience, discovery URL) vs SigV4
7. CloudWatch logs / traces: Runtime log group `/aws/bedrock-agentcore/runtimes/<id>-*`, Lambda logs, Gateway logs, X-Ray/Transaction Search.

## Multi-agent patterns (Strands)

| Pattern | What it is | Pick when |
|---|---|---|
| Agents-as-tools | Specialist agents wrapped in `@tool`; an orchestrator calls them | Default. Clear delegation, one coordinator, simplest to debug and tune via descriptions |
| Swarm | Agents hand off to each other autonomously with shared context | Task path is unknown, agents need to pass control among themselves |
| Graph | Deterministic nodes and edges, conditional routing | Fixed workflow, ordered steps, branching or loops you must control |
| A2A | Agents as separate services speaking the A2A protocol (agent card + JSON-RPC); each deployed on its own Runtime | Required by the challenge, or agents must be independently deployed and discovered across runtimes |

Rule of thumb: start with agents-as-tools. Use Graph if order must be guaranteed. Use Swarm only if handoffs are really dynamic. Use A2A when the task says A2A or agents live in separate runtimes.
