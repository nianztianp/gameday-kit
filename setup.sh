#!/usr/bin/env bash
# Idempotent; continues on error (no set -e).
export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
  echo ">> installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh || pip install --user uv
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

echo ">> installing python packages"
pip install --user -q "strands-agents[a2a]" strands-agents-tools bedrock-agentcore bedrock-agentcore-starter-toolkit \
  || echo "!! pip install failed"

echo ">> warming MCP server caches"
for p in strands-agents-mcp-server awslabs.amazon-bedrock-agentcore-mcp-server awslabs.aws-documentation-mcp-server; do
  uvx "$p" --help >/dev/null 2>&1 </dev/null || echo "!! could not fetch $p"
done

echo ">> MCP status"
claude mcp list || echo "!! claude mcp list failed"
chmod +x recon.sh 2>/dev/null
exit 0
