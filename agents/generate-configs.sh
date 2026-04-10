#!/usr/bin/env bash
set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$HOME"

echo "Generating agent configs in $AGENTS_DIR ..."

# --- developer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/developer.md" \
  --arg vercel_react "skill://${HOME_DIR}/.agent/skills/vercel-react-best-practices/*/SKILL.md" \
  --arg vercel_comp "skill://${HOME_DIR}/.agent/skills/vercel-composition-patterns/*/SKILL.md" \
  --arg frontend "skill://${HOME_DIR}/.agents/skills/frontend-patterns/SKILL.md" \
  '{
    name: "developer",
    description: "Developer Agent that writes high-quality, maintainable code based on specifications",
    model: "claude-opus-4.6",
    tools: ["*", "@builtin"],
    allowedTools: ["@builtin", "fs_*", "execute_bash"],
    useLegacyMcpJson: false,
    resources: [
      "file://CLAUDE.md",
      "file://.kiro/steering/*.md",
      "file://README.md",
      "file://package.json",
      "skill://.kiro/skills/*/SKILL.md",
      $vercel_react,
      $vercel_comp,
      $frontend
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/developer.json"

# --- reviewer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/reviewer.md" \
  --arg vercel_react "file://${HOME_DIR}/.agent/skills/vercel-react-best-practices/**/*.md" \
  --arg vercel_comp "file://${HOME_DIR}/.agent/skills/vercel-composition-patterns/**/*.md" \
  '{
    name: "reviewer",
    description: "Code Reviewer Agent that performs thorough code reviews and ensures quality standards",
    model: "claude-opus-4.6",
    tools: ["@builtin", "*"],
    allowedTools: ["@builtin", "fs_*", "execute_bash"],
    useLegacyMcpJson: false,
    resources: [
      "skill://.kiro/skills/*/SKILL.md",
      "file:///./CLAUDE.md",
      "file://.kiro/steering/*.md",
      $vercel_react,
      $vercel_comp
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/reviewer.json"

# --- designer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/designer.md" \
  '{
    name: "designer",
    description: "Designer Agent that reads Figma designs and extracts design specifications for implementation",
    model: "claude-opus-4.6",
    tools: ["*"],
    allowedTools: ["@builtin", "fs_*", "execute_bash", "@figma-developer-mcp"],
    useLegacyMcpJson: false,
    resources: [],
    mcpServers: {
      "figma-developer-mcp": {
        type: "stdio",
        command: "npx",
        args: ["-y", "figma-developer-mcp", "--stdio"]
      }
    },
    prompt: $prompt
  }' > "$AGENTS_DIR/designer.json"

# --- explorer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/explorer.md" \
  --arg exa_skill "skill://${HOME_DIR}/.kiro/skills/get-code-context-exa/SKILL.md" \
  --arg exa_key "${EXA_API_KEY:-}" \
  '{
    name: "explorer",
    description: "Explorer Agent that investigates codebases, reads documentation, and researches library usage via Context7 and Exa",
    model: "claude-opus-4.6",
    tools: ["@builtin", "*"],
    allowedTools: ["@builtin", "fs_*", "execute_bash", "@context7", "@exa"],
    useLegacyMcpJson: false,
    resources: [
      $exa_skill,
      "skill://.kiro/skills/*/SKILL.md",
      "file://.kiro/steering/*.md"
    ],
    mcpServers: {
      context7: {
        type: "stdio",
        command: "npx",
        args: ["-y", "@upstash/context7-mcp"]
      },
      exa: {
        type: "remote",
        url: ("https://mcp.exa.ai/mcp?exaApiKey=" + $exa_key)
      }
    },
    prompt: $prompt
  }' > "$AGENTS_DIR/explorer.json"

# --- simplifier ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/simplifier.md" \
  '{
    name: "simplifier",
    description: "Code Simplifier Agent that refines code for clarity, consistency, and maintainability while preserving functionality",
    model: "claude-opus-4.6",
    tools: ["@builtin", "*"],
    allowedTools: ["@builtin", "fs_*", "execute_bash", "@git"],
    useLegacyMcpJson: false,
    resources: [],
    mcpServers: {
      git: {
        type: "stdio",
        command: "uvx",
        args: ["mcp-server-git"],
        env: {
          GIT_CONFIG_GLOBAL: "/dev/null"
        }
      }
    },
    prompt: $prompt
  }' > "$AGENTS_DIR/simplifier.json"

# --- tester ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/tester.md" \
  '{
    name: "tester",
    description: "Test Engineer Agent that designs test suites, writes tests, analyzes coverage gaps, and verifies code changes",
    model: "claude-opus-4.6",
    tools: ["*", "@builtin"],
    allowedTools: ["@builtin", "fs_*", "execute_bash"],
    useLegacyMcpJson: false,
    resources: [
      "file://CLAUDE.md",
      "file://.kiro/steering/*.md",
      "file://README.md",
      "file://package.json",
      "skill://.kiro/skills/*/SKILL.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/tester.json"

# --- debugger ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/debugger.md" \
  '{
    name: "debugger",
    description: "Debugger Agent that investigates user-reported issues, confirms root causes, and produces investigation reports",
    model: "claude-opus-4.6",
    tools: ["@builtin", "*"],
    allowedTools: ["@builtin", "fs_*", "execute_bash"],
    useLegacyMcpJson: false,
    resources: [
      "file://.kiro/steering/*.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/debugger.json"

# --- planner ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/planner.md" \
  --arg skills "skill://${HOME_DIR}/.kiro/skills/**/SKILL.md" \
  --arg grill "skill://${HOME_DIR}/.kiro/skills/grill-me/SKILL.md" \
  '{
    name: "planner",
    description: "Planner Agent that analyzes context and produces structured execution plans",
    model: "claude-opus-4.6",
    tools: ["@builtin"],
    allowedTools: ["@builtin", "fs_*"],
    useLegacyMcpJson: false,
    toolsSettings: {
      fs_write: {
        allowedPaths: [".plan/**"],
        fallbackAction: "deny"
      }
    },
    resources: [
      "skill://.kiro/skills/*/SKILL.md",
      $skills,
      $grill,
      "file://.kiro/steering/*.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/planner.json"

# --- code_supervisor ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/code_supervisor.md" \
  --arg skills "skill://${HOME_DIR}/.kiro/skills/**/SKILL.md" \
  --arg notify "${HOME_DIR}/.kiro/hooks/cmux-notify.sh" \
  '{
    name: "code_supervisor",
    prompt: $prompt,
    model: "claude-opus-4.6",
    description: "Coding Supervisor Agent that orchestrates and delegates tasks to specialized agents",
    tools: ["*", "@builtin", "use_subagent"],
    allowedTools: ["fs_*", "@git", "use_subagent"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+a",
    toolsSettings: {
      fs_write: {
        allowedPaths: [".plan/**"],
        fallbackAction: "deny"
      },
      execute_bash: {
        allowedCommands: ["mkdir .*"],
        denyByDefault: true
      },
      subagent: {
        availableAgents: ["planner", "designer", "developer", "explorer", "reviewer", "simplifier", "tester", "debugger"],
        trustedAgents: ["planner", "designer", "developer", "explorer", "reviewer", "simplifier", "tester", "debugger"]
      }
    },
    resources: [
      "skill://.kiro/skills/*/SKILL.md",
      "file://.kiro/steering/*.md",
      $skills
    ],
    mcpServers: {
      git: {
        type: "stdio",
        command: "uvx",
        args: ["mcp-server-git"],
        env: {
          GIT_CONFIG_GLOBAL: "/dev/null"
        }
      }
    },
    hooks: {
      stop: [
        {
          command: $notify,
          description: "Notify via cmux when response completes"
        }
      ]
    }
  }' > "$AGENTS_DIR/code_supervisor.json"

echo "Done. Generated 9 agent configs:"
for f in developer reviewer designer explorer simplifier tester debugger planner code_supervisor; do
  echo "  ✓ $AGENTS_DIR/$f.json"
done
