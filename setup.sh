#!/usr/bin/env bash
# Idempotent; continues on error (no set -e).
export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
  echo ">> installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh || pip install --user uv
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

if ! command -v claude >/dev/null 2>&1; then
  echo ">> installing Claude Code CLI"
  curl -fsSL https://claude.ai/install.sh | bash || npm i -g @anthropic-ai/claude-code || echo "!! claude install failed"
fi
if ! command -v codex >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  echo ">> installing Codex CLI"
  npm i -g @openai/codex >/dev/null 2>&1 || echo "!! codex install failed"
fi
mkdir -p "$HOME/.claude" "$HOME/.codex"  # agent-toolkit detects agents by these dirs

echo ">> VS Code extension (Claude Code)"
ext_ok=
# Remote IDEs: the plain `code` on PATH can be a stub; the remote-cli binary is the real one.
for c in $(ls -d "$HOME"/.vscode-remote/bin/*/bin/remote-cli/code "$HOME"/.vscode-server/bin/*/bin/remote-cli/code \
             "$HOME"/.openvscode-server/bin/*/bin/remote-cli/openvscode-server 2>/dev/null) \
         code-server openvscode-server code; do
  if command -v "$c" >/dev/null 2>&1; then
    "$c" --install-extension anthropic.claude-code >/dev/null 2>&1 && ext_ok=1 && echo "   installed via $c" && break
  fi
done
[ -n "$ext_ok" ] || echo "!! could not install extension; install 'Claude Code' from the Extensions panel (terminal 'claude' works regardless)"

echo ">> installing python packages"
pip install --user -q "strands-agents[a2a]" strands-agents-tools bedrock-agentcore bedrock-agentcore-starter-toolkit \
  || echo "!! pip install failed"

echo ">> warming MCP server caches"
for p in strands-agents-mcp-server awslabs.amazon-bedrock-agentcore-mcp-server awslabs.aws-documentation-mcp-server; do
  uvx "$p" --help >/dev/null 2>&1 </dev/null || echo "!! could not fetch $p"
done

# Runs after Codex/Claude are installed so it detects both (Codex skills go to ~/.agents/skills).
echo ">> AWS agent toolkit (AWS skills + aws-mcp server, user-level)"
if command -v aws >/dev/null 2>&1; then
  aws configure agent-toolkit --yes >/dev/null 2>&1 || echo "!! aws configure agent-toolkit failed (try upgrading AWS CLI v2)"
else
  echo "!! aws CLI not found; skipping agent toolkit"
fi

if command -v codex >/dev/null 2>&1; then
  echo ">> Codex MCP servers (global ~/.codex/config.toml; re-adding overwrites)"
  codex mcp add strands -- uvx strands-agents-mcp-server >/dev/null || echo "!! codex add strands failed"
  codex mcp add bedrock-agentcore-mcp-server --env AGENTCORE_ENABLE_TOOLS=docs \
    -- uvx awslabs.amazon-bedrock-agentcore-mcp-server@latest >/dev/null || echo "!! codex add agentcore failed"
  codex mcp add aws-documentation -- uvx awslabs.aws-documentation-mcp-server@latest >/dev/null \
    || echo "!! codex add aws-documentation failed"
  codex mcp list || true
fi

echo ">> MCP status"
command -v claude >/dev/null 2>&1 && { claude mcp list || echo "!! claude mcp list failed"; }
chmod +x recon.sh 2>/dev/null
exit 0
