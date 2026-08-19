---
name: my-default
tools: ["@builtin", "@mcp"]
includeMcpJson: false
includePowers: false
mcpServers:
  figma:
    command: npx
    args: ["-y", "figma-developer-mcp", "--stdio"]
    env:
      FIGMA_API_KEY: "${FIGMA_API_KEY}"
toolsSettings:
  subagent:
    availableAgents: ["*"]
    trustedAgents: ["*"]
resources:
  - file://AGENTS.md
  - file://.kiro/steering/*.md
  - skill://~/.agents/skills/*/SKILL.md
---


