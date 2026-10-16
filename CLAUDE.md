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
4. Ask before creating IAM roles or any new AWS resource.
5. AgentCore Runtime containers are **arm64**. Build with `--platform linux/arm64` (or use the starter toolkit's CodeBuild path).
6. Verify AgentCore / Strands / A2A APIs via the docs MCP servers (strands, bedrock-agentcore-mcp-server, aws-documentation), not memory. Signatures change.
7. Tool descriptions and system prompts are scoring levers. Word them precisely: when to call, what it takes, what it returns, what not to use it for.

## Tooling

- MCP: `strands`, `bedrock-agentcore-mcp-server` (docs tools only), `aws-documentation` for API lookups. `aws-mcp` (from `aws configure agent-toolkit`) runs AWS API calls with the lab credentials: fine for reads; rule 4 still applies to anything that creates/changes resources.
- AWS skills worth loading: `amazon-bedrock` (AgentCore Runtime/Gateway/Identity, model IDs), `aws-iam` (execution/outbound roles, trust policies), `aws-serverless` (Lambda tools), `aws-auth` (Cognito JWT for Gateway inbound auth), `aws-observability` (CloudWatch logs/traces), `aws-sdk-python-usage` (boto3), `aws-containers` (ECR, arm64 images).
- This file is also `AGENTS.md` (symlink) for Codex.

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
