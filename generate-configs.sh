#!/usr/bin/env bash
set -euo pipefail

KIRO_DIR="$HOME/.kiro"
AGENTS_DIR="$KIRO_DIR/agents"
HOME_DIR="$HOME"

if [ -z "${EXA_API_KEY:-}" ]; then echo "ERROR: EXA_API_KEY environment variable is not set" >&2; exit 1; fi
if ! command -v jq &>/dev/null; then echo "ERROR: jq is required but not found" >&2; exit 1; fi

mkdir -p "$AGENTS_DIR" "$KIRO_DIR/settings" "$KIRO_DIR/hooks" "$KIRO_DIR/skills/cartography/scripts" "$KIRO_DIR/skills/council-session"

RTK_HOOK="$KIRO_DIR/hooks/rtk-rewrite.sh"
# Post-process an agent JSON to add the RTK preToolUse hook (idempotent via jq merge)
inject_rtk_hook() {
  local agent_file="$1"
  jq --arg hook "$RTK_HOOK" \
    '.hooks.preToolUse = (.hooks.preToolUse // []) + [{ command: $hook, matcher: "execute_bash" }]' \
    "$agent_file" > "${agent_file}.tmp" && mv "${agent_file}.tmp" "$agent_file"
}

RTK_SPAWN_HOOK="$KIRO_DIR/hooks/rtk-rules.sh"
inject_rtk_spawn_hook() {
  local agent_file="$1"
  jq --arg hook "$RTK_SPAWN_HOOK" \
    '.hooks.agentSpawn = (.hooks.agentSpawn // []) + [{ command: $hook }]' \
    "$agent_file" > "${agent_file}.tmp" && mv "${agent_file}.tmp" "$agent_file"
}

inject_caveman_hook() {
  local f="$1"
  jq --arg hook "$KIRO_DIR/hooks/caveman.sh" \
    '.hooks.agentSpawn = (.hooks.agentSpawn // []) + [{ command: $hook }]' \
    "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
}

inject_locale_hook() {
  local f="$1"
  jq --arg hook "$KIRO_DIR/hooks/locale.sh" \
    '.hooks.agentSpawn = (.hooks.agentSpawn // []) + [{ command: $hook }]' \
    "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
}

echo "Generating Kiro configs..."

# --- developer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/developer.md" \
  --arg skills "skill://${HOME_DIR}/.kiro/skills/**/SKILL.md" \
  '{
    name: "developer",
    description: "Developer Agent that writes high-quality, maintainable code based on specifications",
    model: "claude-opus-4.6",
    tools: ["*", "@builtin"],
    allowedTools: ["@builtin", "fs_*", "execute_bash"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+shift+d",
    welcomeMessage: "Ready to implement. What'\''s the task?",
    resources: [
      "file://CLAUDE.md",
      "file://.kiro/steering/*.md",
      "file://README.md",
      "file://package.json",
      "skill://.kiro/skills/*/SKILL.md",
      $skills
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/developer.json"
inject_rtk_hook "$AGENTS_DIR/developer.json"
inject_rtk_spawn_hook "$AGENTS_DIR/developer.json"
inject_caveman_hook "$AGENTS_DIR/developer.json"
inject_locale_hook "$AGENTS_DIR/developer.json"

# --- reviewer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/reviewer.md" \
  --arg skills "skill://${HOME_DIR}/.kiro/skills/**/SKILL.md" \
  '{
    name: "reviewer",
    description: "Code Reviewer Agent that performs thorough code reviews and ensures quality standards",
    model: "claude-opus-4.6",
    tools: ["@builtin", "*"],
    allowedTools: ["@builtin", "fs_*", "execute_bash"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+r",
    welcomeMessage: "What code needs review?",
    resources: [
      "skill://.kiro/skills/*/SKILL.md",
      "file:///./CLAUDE.md",
      "file://.kiro/steering/*.md",
      $skills
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/reviewer.json"
inject_rtk_hook "$AGENTS_DIR/reviewer.json"
inject_rtk_spawn_hook "$AGENTS_DIR/reviewer.json"
inject_caveman_hook "$AGENTS_DIR/reviewer.json"
inject_locale_hook "$AGENTS_DIR/reviewer.json"

# --- designer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/designer.md" \
  --arg skills "skill://${HOME_DIR}/.kiro/skills/**/SKILL.md" \
  '{
    name: "designer",
    description: "Designer Agent that reads Figma designs and extracts design specifications for implementation",
    model: "claude-opus-4.6",
    tools: ["*"],
    allowedTools: ["@builtin", "fs_*", "execute_bash", "@figma-developer-mcp"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+shift+f",
    welcomeMessage: "What UI/UX needs attention?",
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
inject_rtk_hook "$AGENTS_DIR/designer.json"
inject_rtk_spawn_hook "$AGENTS_DIR/designer.json"
inject_caveman_hook "$AGENTS_DIR/designer.json"
inject_locale_hook "$AGENTS_DIR/designer.json"

# --- explorer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/explorer.md" \
  --arg skills "skill://${HOME_DIR}/.kiro/skills/**/SKILL.md" \
  --arg exa_key "${EXA_API_KEY}" \
  '{
    name: "explorer",
    description: "Explorer Agent that investigates codebases, reads documentation, and researches library usage via Context7 and Exa",
    model: "claude-opus-4.6",
    tools: ["@builtin", "*"],
    allowedTools: ["@builtin", "fs_*", "execute_bash", "@context7", "@exa", "@github-grep"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+e",
    welcomeMessage: "What do you need to find in the codebase?",
    toolsSettings: {
      fs_write: {
        allowedPaths: [".plan/**"],
        fallbackAction: "deny"
      },
    },
    resources: [
      $skills,
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
      },
      "github-grep": {
        type: "remote",
        url: "https://mcp.grep.app"
      }
    },
    prompt: $prompt
  }' > "$AGENTS_DIR/explorer.json"
inject_rtk_hook "$AGENTS_DIR/explorer.json"
inject_rtk_spawn_hook "$AGENTS_DIR/explorer.json"
inject_caveman_hook "$AGENTS_DIR/explorer.json"
inject_locale_hook "$AGENTS_DIR/explorer.json"

# --- simplifier ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/simplifier.md" \
  --arg skills "skill://${HOME_DIR}/.kiro/skills/**/SKILL.md" \
  '{
    name: "simplifier",
    description: "Code Simplifier Agent that refines code for clarity, consistency, and maintainability while preserving functionality",
    model: "claude-opus-4.6",
    tools: ["@builtin", "*"],
    allowedTools: ["@builtin", "fs_*", "execute_bash", "@git"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+shift+s",
    welcomeMessage: "What code needs simplification?",
    resources: [
      $skills,
      "skill://.kiro/skills/*/SKILL.md",
      "file://.kiro/steering/*.md"
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
    prompt: $prompt
  }' > "$AGENTS_DIR/simplifier.json"
inject_rtk_hook "$AGENTS_DIR/simplifier.json"
inject_rtk_spawn_hook "$AGENTS_DIR/simplifier.json"
inject_caveman_hook "$AGENTS_DIR/simplifier.json"
inject_locale_hook "$AGENTS_DIR/simplifier.json"

# --- tester ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/tester.md" \
  --arg skills "skill://${HOME_DIR}/.kiro/skills/**/SKILL.md" \
  '{
    name: "tester",
    description: "Test Engineer Agent that designs test suites, writes tests, analyzes coverage gaps, and verifies code changes",
    model: "claude-opus-4.6",
    tools: ["*", "@builtin"],
    allowedTools: ["@builtin", "fs_*", "execute_bash"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+t",
    welcomeMessage: "What needs testing?",
    resources: [
      $skills,
      "file://.kiro/steering/*.md",
      "file://README.md",
      "skill://.kiro/skills/*/SKILL.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/tester.json"
inject_rtk_hook "$AGENTS_DIR/tester.json"
inject_rtk_spawn_hook "$AGENTS_DIR/tester.json"
inject_caveman_hook "$AGENTS_DIR/tester.json"
inject_locale_hook "$AGENTS_DIR/tester.json"

# --- debugger ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/debugger.md" \
  --arg skills "skill://${HOME_DIR}/.kiro/skills/**/SKILL.md" \
  '{
    name: "debugger",
    description: "Debugger Agent that investigates user-reported issues, confirms root causes, and produces investigation reports",
    model: "claude-opus-4.6",
    tools: ["@builtin", "*"],
    allowedTools: ["@builtin", "fs_*", "execute_bash"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+b",
    welcomeMessage: "What issue are you investigating?",
    resources: [
      $skills,
      "file://.kiro/steering/*.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/debugger.json"
inject_rtk_hook "$AGENTS_DIR/debugger.json"
inject_rtk_spawn_hook "$AGENTS_DIR/debugger.json"
inject_caveman_hook "$AGENTS_DIR/debugger.json"
inject_locale_hook "$AGENTS_DIR/debugger.json"

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
    keyboardShortcut: "ctrl+p",
    welcomeMessage: "What task needs a plan?",
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
inject_caveman_hook "$AGENTS_DIR/planner.json"
inject_locale_hook "$AGENTS_DIR/planner.json"

# --- code_supervisor ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/code_supervisor.md" \
  --arg skills "skill://${HOME_DIR}/.kiro/skills/**/SKILL.md" \
  --arg notify "${HOME_DIR}/.kiro/hooks/cmux-notify.sh" \
  --arg phase_reminder "$KIRO_DIR/hooks/phase-reminder.sh" \
  '{
    name: "code_supervisor",
    prompt: $prompt,
    model: "claude-opus-4.6",
    description: "Coding Supervisor Agent that orchestrates and delegates tasks to specialized agents",
    tools: ["read", "use_subagent", "todo", "thinking", "introspect", "session", "@git"],
    allowedTools: ["read", "use_subagent", "todo", "thinking", "introspect", "session", "@git"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+a",
    welcomeMessage: "What would you like to build? I'\''ll coordinate the team.",
    toolsSettings: {
      shell: {
        autoAllowReadonly: true
      },
      subagent: {
        availableAgents: ["planner", "designer", "developer", "explorer", "reviewer", "simplifier", "tester", "debugger", "librarian", "councillor-a", "councillor-b", "councillor-c", "council-master"],
        trustedAgents: ["planner", "designer", "developer", "explorer", "reviewer", "simplifier", "tester", "debugger", "librarian", "councillor-a", "councillor-b", "councillor-c", "council-master"]
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
      ],
      userPromptSubmit: [
        {
          command: $phase_reminder
        }
      ]
    }
  }' > "$AGENTS_DIR/code_supervisor.json"
inject_caveman_hook "$AGENTS_DIR/code_supervisor.json"
inject_locale_hook "$AGENTS_DIR/code_supervisor.json"

# --- librarian ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/librarian.md" \
  --arg exa_key "${EXA_API_KEY}" \
  --arg exa_skill "skill://${HOME_DIR}/.kiro/skills/get-code-context-exa/SKILL.md" \
  --arg c7_skill "skill://${HOME_DIR}/.kiro/skills/context7-auto-research/SKILL.md" \
  '{
    name: "librarian",
    description: "Library documentation and API research specialist",
    model: "claude-opus-4.6",
    tools: ["@builtin", "*"],
    allowedTools: ["@builtin", "fs_*", "@context7", "@exa", "@github-grep"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+l",
    welcomeMessage: "What library or API do you need docs for?",
    resources: [
      $exa_skill,
      $c7_skill,
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
      },
      "github-grep": {
        type: "remote",
        url: "https://mcp.grep.app"
      }
    },
    prompt: $prompt
  }' > "$AGENTS_DIR/librarian.json"
inject_caveman_hook "$AGENTS_DIR/librarian.json"
inject_locale_hook "$AGENTS_DIR/librarian.json"

# --- researcher ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/researcher.md" \
  --arg exa_key "${EXA_API_KEY}" \
  --arg exa_skill "skill://${HOME_DIR}/.kiro/skills/web-search-advanced-research-paper-exa/SKILL.md" \
  '{
    name: "researcher",
    description: "Research Agent that finds, analyzes, and explains academic papers using Exa",
    model: "claude-opus-4.6",
    tools: ["*"],
    allowedTools: ["@builtin", "@exa"],
    useLegacyMcpJson: false,
    keyboardShortcut: "ctrl+shift+r",
    welcomeMessage: "What research topic or paper are you looking for?",
    resources: [$exa_skill],
    mcpServers: {
      exa: {
        type: "remote",
        url: ("https://mcp.exa.ai/mcp?exaApiKey=" + $exa_key)
      }
    },
    prompt: $prompt
  }' > "$AGENTS_DIR/researcher.json"
inject_caveman_hook "$AGENTS_DIR/researcher.json"
inject_locale_hook "$AGENTS_DIR/researcher.json"

# --- councillor-a (Claude Opus) ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/councillor-a.md" \
  '{
    name: "councillor-a",
    description: "Council advisor (Opus). Read-only codebase analysis for multi-model consensus.",
    model: "claude-opus-4.6",
    tools: ["@builtin"],
    allowedTools: ["@builtin", "fs_*"],
    useLegacyMcpJson: false,
    toolsSettings: {
      fs_write: { deniedPaths: ["**"], fallbackAction: "deny" },
      execute_bash: { denyByDefault: true }
    },
    resources: [
      "file://.kiro/steering/*.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/councillor-a.json"
inject_caveman_hook "$AGENTS_DIR/councillor-a.json"
inject_locale_hook "$AGENTS_DIR/councillor-a.json"

# --- councillor-b (Claude Sonnet) ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/councillor-b.md" \
  '{
    name: "councillor-b",
    description: "Council advisor (Sonnet). Read-only codebase analysis for multi-model consensus.",
    model: "glm-5",
    tools: ["@builtin"],
    allowedTools: ["@builtin", "fs_*"],
    useLegacyMcpJson: false,
    toolsSettings: {
      fs_write: { deniedPaths: ["**"], fallbackAction: "deny" },
      execute_bash: { denyByDefault: true }
    },
    resources: [
      "file://.kiro/steering/*.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/councillor-b.json"
inject_caveman_hook "$AGENTS_DIR/councillor-b.json"
inject_locale_hook "$AGENTS_DIR/councillor-b.json"

# --- councillor-c ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/councillor-c.md" \
  '{
    name: "councillor-c",
    description: "Council advisor. Read-only codebase analysis for multi-model consensus.",
    model: "claude-opus-4.5",
    tools: ["@builtin"],
    allowedTools: ["@builtin", "fs_*"],
    useLegacyMcpJson: false,
    toolsSettings: {
      fs_write: { deniedPaths: ["**"], fallbackAction: "deny" },
      execute_bash: { denyByDefault: true }
    },
    resources: [
      "file://.kiro/steering/*.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/councillor-c.json"
inject_caveman_hook "$AGENTS_DIR/councillor-c.json"
inject_locale_hook "$AGENTS_DIR/councillor-c.json"

# --- council-master ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/council-master.md" \
  '{
    name: "council-master",
    description: "Council synthesis engine. Reviews councillor responses and produces the final answer.",
    model: "claude-opus-4.6",
    tools: ["@builtin"],
    allowedTools: ["@builtin", "fs_*"],
    useLegacyMcpJson: false,
    toolsSettings: {
      fs_write: { deniedPaths: ["**"], fallbackAction: "deny" },
      execute_bash: { denyByDefault: true }
    },
    prompt: $prompt
  }' > "$AGENTS_DIR/council-master.json"
inject_caveman_hook "$AGENTS_DIR/council-master.json"
inject_locale_hook "$AGENTS_DIR/council-master.json"

# --- mcp.json ---
jq -n \
  --arg exa_key "${EXA_API_KEY}" \
  '{
    mcpServers: {
      git: { command: "uvx", args: ["mcp-server-git"], env: { GIT_CONFIG_GLOBAL: "/dev/null" } },
      context7: { command: "npx", args: ["-y", "@upstash/context7-mcp"] },
      "chrome-devtools": { command: "npx", args: ["-y", "chrome-devtools-mcp@latest"], autoApprove: ["take_screenshot", "list_pages"], disabled: true },
      "figma-developer-mcp": { command: "npx", args: ["-y", "figma-developer-mcp", "--stdio"] },
      exa: { url: ("https://mcp.exa.ai/mcp?exaApiKey=" + $exa_key), autoApprove: ["web_search_exa"] },
      "github-grep": { url: "https://mcp.grep.app" }
    }
  }' > "$KIRO_DIR/settings/mcp.json"

# --- Summary ---
echo ""
echo "Kiro configuration complete:"
echo "  Agents:"
for f in developer reviewer designer explorer simplifier tester debugger planner code_supervisor librarian researcher councillor-a councillor-b councillor-c council-master; do
  echo "    ✓ $AGENTS_DIR/$f.json"
done
echo "  Settings:"
echo "    ✓ $KIRO_DIR/settings/mcp.json"
echo "  Hooks (managed separately in hooks/):"
for f in phase-reminder caveman locale rtk-rewrite rtk-rules cmux-notify; do
  if [ -f "$KIRO_DIR/hooks/$f.sh" ]; then
    echo "    ✓ $KIRO_DIR/hooks/$f.sh"
  else
    echo "    ⚠ $KIRO_DIR/hooks/$f.sh not found"
  fi
done
echo ""
echo "Note: .md prompt files and SKILL.md files are NOT generated by this script."
"
