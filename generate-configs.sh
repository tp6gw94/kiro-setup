#!/usr/bin/env bash
set -euo pipefail

KIRO_DIR="$HOME/.kiro"
AGENTS_DIR="$KIRO_DIR/agents"
HOME_DIR="$HOME"
KIRO_SKILLS_URI="skill://${HOME_DIR}/.kiro/skills/**/SKILL.md"

if [ -z "${EXA_API_KEY:-}" ]; then echo "ERROR: EXA_API_KEY environment variable is not set" >&2; exit 1; fi
if ! command -v jq &>/dev/null; then echo "ERROR: jq is required but not found" >&2; exit 1; fi

mkdir -p \
  "$AGENTS_DIR" \
  "$KIRO_DIR/settings" \
  "$KIRO_DIR/hooks" \
  "$KIRO_DIR/hooks/code_supervisor" \
  "$KIRO_DIR/hooks/planner" \
  "$KIRO_DIR/hooks/plan_writers" \
  "$KIRO_DIR/hooks/source_writing" \
  "$KIRO_DIR/hooks/shell" \
  "$KIRO_DIR/skills/cartography/scripts" \
  "$KIRO_DIR/skills/council-session"

RTK_HOOK="$KIRO_DIR/hooks/shell/rtk-rewrite.js"
# Post-process an agent JSON to add the RTK preToolUse hook (idempotent via jq merge)
inject_rtk_hook() {
  local agent_file="$1"
  jq --arg hook "$RTK_HOOK" \
    '.hooks.preToolUse = (.hooks.preToolUse // []) + [{ command: $hook, matcher: "shell" }]' \
    "$agent_file" > "${agent_file}.tmp" && mv "${agent_file}.tmp" "$agent_file"
}

DEVELOPER_RM_HOOK="$KIRO_DIR/hooks/shell/validate-local-rm.js"
inject_developer_rm_hook() {
  local agent_file="$1"
  jq --arg hook "$DEVELOPER_RM_HOOK" \
    '.hooks.preToolUse = (.hooks.preToolUse // []) + [{ command: $hook, matcher: "shell" }]' \
    "$agent_file" > "${agent_file}.tmp" && mv "${agent_file}.tmp" "$agent_file"
}

RTK_SPAWN_HOOK="$KIRO_DIR/hooks/shell/rtk-rules.sh"
inject_rtk_spawn_hook() {
  local agent_file="$1"
  jq --arg hook "$RTK_SPAWN_HOOK" \
    '.hooks.agentSpawn = (.hooks.agentSpawn // []) + [{ command: $hook }]' \
    "$agent_file" > "${agent_file}.tmp" && mv "${agent_file}.tmp" "$agent_file"
}

DEVELOPER_PLAN_HOOK="$KIRO_DIR/hooks/source_writing/validate-developer-plan.js"
inject_developer_plan_hook() {
  local agent_file="$1"
  jq --arg hook "$DEVELOPER_PLAN_HOOK" \
    '.hooks.preToolUse = (.hooks.preToolUse // []) + [
      { command: $hook, matcher: "write" },
      { command: $hook, matcher: "code" },
      { command: $hook, matcher: "shell" }
    ]' \
    "$agent_file" > "${agent_file}.tmp" && mv "${agent_file}.tmp" "$agent_file"
}

ARTIFACT_PLAN_WRITE_HOOK="$KIRO_DIR/hooks/plan_writers/validate-artifact-plan-write.js"
inject_plan_folder_write_hook() {
  local agent_file="$1"
  jq --arg hook "$ARTIFACT_PLAN_WRITE_HOOK" \
    '.hooks.preToolUse = (.hooks.preToolUse // []) + [{ command: $hook, matcher: "write" }]' \
    "$agent_file" > "${agent_file}.tmp" && mv "${agent_file}.tmp" "$agent_file"
}

PLANNER_PLAN_WRITE_HOOK="$KIRO_DIR/hooks/planner/validate-planner-plan-write.js"
inject_planner_plan_write_hook() {
  local agent_file="$1"
  jq --arg hook "$PLANNER_PLAN_WRITE_HOOK" \
    '.hooks.preToolUse = (.hooks.preToolUse // []) + [{ command: $hook, matcher: "write" }]' \
    "$agent_file" > "${agent_file}.tmp" && mv "${agent_file}.tmp" "$agent_file"
}

PLANNER_OPEN_TASK_MARKDOWN_HOOK="$KIRO_DIR/hooks/planner/open-task-markdown.js"
inject_planner_task_markdown_hook() {
  local agent_file="$1"
  jq --arg hook "$PLANNER_OPEN_TASK_MARKDOWN_HOOK" \
    '.hooks.postToolUse = (.hooks.postToolUse // []) + [{ command: $hook, matcher: "write" }]' \
    "$agent_file" > "${agent_file}.tmp" && mv "${agent_file}.tmp" "$agent_file"
}

SUPERVISOR_PLAN_WRITE_HOOK="$KIRO_DIR/hooks/code_supervisor/validate-supervisor-plan-write.js"
inject_supervisor_plan_write_hook() {
  local agent_file="$1"
  jq --arg hook "$SUPERVISOR_PLAN_WRITE_HOOK" \
    '.hooks.preToolUse = (.hooks.preToolUse // []) + [{ command: $hook, matcher: "write" }]' \
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
rm -f "$AGENTS_DIR/librarian.json"

# --- developer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/developer.md" \
  --arg skills "$KIRO_SKILLS_URI" \
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "developer",
    description: "Developer Agent that writes high-quality, maintainable code based on specifications",
    model: "claude-opus-4.6",
    tools: ["read", "write", "code", "glob", "grep", "shell", "todo"],
    allowedTools: ["code", "todo"],
    useLegacyMcpJson: false,
    toolsSettings: {
      glob: {
        allowedPaths: ["./"]
      },
      read: {
        allowedPaths: ["./", $home_kiro]
      },
      grep: {
        allowedPaths: ["./"]
      },
      write: {
        allowedPaths: ["./"]
      },
      shell: {
        allowedCommands: [
          "rtk pnpm[[:space:]]+(?:test|typecheck|lint|build)(?:[[:space:]].*)?",
          "rtk pnpm[[:space:]]+(?:run[[:space:]]+)?(?:test|typecheck|lint|build)(?:[[:space:]].*)?",
          "rtk tsc(?:[[:space:]].*)?",
          "rtk cat .*",
          "rtk sed .*",
          "rtk head .*",
          "rtk rm .*"
        ],
        autoAllowReadonly: true,
        denyByDefault: true
      }
    },
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
inject_developer_plan_hook "$AGENTS_DIR/developer.json"
inject_developer_rm_hook "$AGENTS_DIR/developer.json"
inject_rtk_hook "$AGENTS_DIR/developer.json"
inject_rtk_spawn_hook "$AGENTS_DIR/developer.json"
inject_caveman_hook "$AGENTS_DIR/developer.json"
inject_locale_hook "$AGENTS_DIR/developer.json"

# --- reviewer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/reviewer.md" \
  --arg skills "$KIRO_SKILLS_URI" \
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "reviewer",
    model: "claude-opus-4.6",
    tools: ["read", "write", "grep", "glob", "shell"],
    allowedTools: [],
    toolsSettings: {
      glob: {
        allowedPaths: ["./"]
      },
      read: {
        allowedPaths: ["./", $home_kiro]
      },
      grep: {
        allowedPaths: ["./"]
      },
      write: {
        allowedPaths: ["./.plan"]
      },
      shell: {
        allowedCommands: [
          "rtk git[[:space:]]+(?:status|diff|show|log|rev-parse|merge-base)(?:[[:space:]].*)?",
          "rtk pnpm[[:space:]]+(?:test|typecheck|lint|build)(?:[[:space:]].*)?",
          "rtk pnpm[[:space:]]+run[[:space:]]+(?:test|typecheck|lint|build)(?:[[:space:]].*)?",
          "rtk npm[[:space:]]+run[[:space:]]+(?:test|typecheck|lint|build)(?:[[:space:]].*)?",
          "rtk agent-browser(?:[[:space:]].*)?",
          "rtk npx[[:space:]]+agent-browser(?:[[:space:]].*)?",
          "rtk cat .*",
          "rtk head .*"
        ],
        autoAllowReadonly: true,
        denyByDefault: true
      }
    },
    useLegacyMcpJson: false,
    resources: [
      "skill://.kiro/skills/*/SKILL.md",
      "file:///./CLAUDE.md",
      "file://.kiro/steering/*.md",
      $skills
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/reviewer.json"
inject_plan_folder_write_hook "$AGENTS_DIR/reviewer.json"
inject_rtk_hook "$AGENTS_DIR/reviewer.json"
inject_rtk_spawn_hook "$AGENTS_DIR/reviewer.json"
inject_caveman_hook "$AGENTS_DIR/reviewer.json"
inject_locale_hook "$AGENTS_DIR/reviewer.json"

# --- designer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/designer.md" \
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "designer",
    description: "Designer Agent that reads Figma designs and extracts design specifications for implementation",
    model: "claude-opus-4.6",
    tools: ["read", "write", "@figma-developer-mcp"],
    allowedTools: ["@figma-developer-mcp"],
    useLegacyMcpJson: false,
    toolsSettings: {
      read: {
        allowedPaths: ["./.plan", $home_kiro],
      },
      write: { 
        allowedPaths: ["./.plan"],
      }
    },
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
inject_plan_folder_write_hook "$AGENTS_DIR/designer.json"
inject_rtk_hook "$AGENTS_DIR/designer.json"
inject_rtk_spawn_hook "$AGENTS_DIR/designer.json"
inject_caveman_hook "$AGENTS_DIR/designer.json"
inject_locale_hook "$AGENTS_DIR/designer.json"

# --- explorer ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/explorer.md" \
  --arg skills "$KIRO_SKILLS_URI" \
  --arg exa_key "${EXA_API_KEY}" \
  '{
    name: "explorer",
    description: "Explorer Agent that investigates codebases, reads documentation, and researches library usage via Context7 and Exa",
    model: "claude-opus-4.6",
    tools: ["read", "write", "grep", "glob", "@context7", "@exa", "@github-grep"],
    allowedTools: ["read", "grep", "glob", "@context7", "@exa", "@github-grep"],
    useLegacyMcpJson: false,
    toolsSettings: {
      write: {
        allowedPaths: ["./.plan"]
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
        url: "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa",
        headers: {
          "x-api-key": $exa_key
        }
      },
      "github-grep": {
        type: "remote",
        url: "https://mcp.grep.app"
      }
    },
    prompt: $prompt
  }' > "$AGENTS_DIR/explorer.json"
inject_plan_folder_write_hook "$AGENTS_DIR/explorer.json"
inject_rtk_hook "$AGENTS_DIR/explorer.json"
inject_rtk_spawn_hook "$AGENTS_DIR/explorer.json"
inject_caveman_hook "$AGENTS_DIR/explorer.json"
inject_locale_hook "$AGENTS_DIR/explorer.json"

# --- simplifier ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/simplifier.md" \
  --arg skills "$KIRO_SKILLS_URI" \
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "simplifier",
    description: "Code Simplifier Agent that refines code for clarity, consistency, and maintainability while preserving functionality",
    model: "claude-opus-4.6",
    tools: ["read", "write", "grep", "glob", "shell", "@git"],
    allowedTools: ["shell", "@git"],
    useLegacyMcpJson: false,
    toolsSettings: {
      glob: {
        allowedPaths: ["./"]
      },
      read: {
        allowedPaths: ["./", $home_kiro]
      },
      grep: {
        allowedPaths: ["./"]
      },
      write: {
        allowedPaths: ["./"]
      },
    },
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
inject_developer_plan_hook "$AGENTS_DIR/simplifier.json"
inject_rtk_hook "$AGENTS_DIR/simplifier.json"
inject_rtk_spawn_hook "$AGENTS_DIR/simplifier.json"
inject_caveman_hook "$AGENTS_DIR/simplifier.json"
inject_locale_hook "$AGENTS_DIR/simplifier.json"

# --- tester ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/tester.md" \
  --arg skills "$KIRO_SKILLS_URI" \
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "tester",
    description: "Test Engineer Agent that designs test suites, writes tests, analyzes coverage gaps, and verifies code changes",
    model: "claude-opus-4.6",
    tools: ["read", "write", "code", "grep", "glob", "shell"],
    allowedTools: ["shell", "code", "grep", "glob"],
    toolsSettings: {
      grep: {
        allowedPaths: ["./"]
      },
      glob: {
        allowedPaths: ["./"]
      },
      read: {
        allowedPaths: ["./", $home_kiro]
      },
      write: {
        allowedPaths: ["./"]
      },
    },
    useLegacyMcpJson: false,
    resources: [
      $skills,
      "file://.kiro/steering/*.md",
      "file://README.md",
      "skill://.kiro/skills/*/SKILL.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/tester.json"
inject_developer_plan_hook "$AGENTS_DIR/tester.json"
inject_rtk_hook "$AGENTS_DIR/tester.json"
inject_rtk_spawn_hook "$AGENTS_DIR/tester.json"
inject_caveman_hook "$AGENTS_DIR/tester.json"
inject_locale_hook "$AGENTS_DIR/tester.json"

# --- debugger ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/debugger.md" \
  --arg skills "$KIRO_SKILLS_URI" \
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "debugger",
    description: "Debugger Agent that investigates user-reported issues, confirms root causes, and produces investigation reports",
    model: "claude-opus-4.6",
    tools: ["read", "write", "glob", "grep", "shell"],
    allowedTools: ["shell"],
    toolsSettings: {
      grep: {
        allowedPaths: ["./"]
      },
      glob: {
        allowedPaths: ["./"]
      },
      read: {
        allowedPaths: ["./", $home_kiro]
      },
      write: {
        allowedPaths: ["./.plan"]
      },
    },
    useLegacyMcpJson: false,
    resources: [
      $skills,
      "file://.kiro/steering/*.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/debugger.json"
inject_plan_folder_write_hook "$AGENTS_DIR/debugger.json"
inject_rtk_hook "$AGENTS_DIR/debugger.json"
inject_rtk_spawn_hook "$AGENTS_DIR/debugger.json"
inject_caveman_hook "$AGENTS_DIR/debugger.json"
inject_locale_hook "$AGENTS_DIR/debugger.json"

# --- planner ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/planner.md" \
  --arg skills "$KIRO_SKILLS_URI" \
  --arg grill "skill://${HOME_DIR}/.kiro/skills/grill-me/SKILL.md" \
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "planner",
    description: "Planner Agent that analyzes context and produces structured execution plans",
    model: "claude-opus-4.6",
    tools: ["read", "write", "grep", "glob", "shell"],
    allowedTools: [],
    useLegacyMcpJson: false,
    welcomeMessage: "What task needs a plan?",
    toolsSettings: {
      shell: {
        allowedCommands: ["rtk cmux markdown .*"],
        denyByDefault: true
      },
      grep: {
        allowedPaths: ["./"]
      },
      glob: {
        allowedPaths: ["./"]
      },
      read: {
        allowedPaths: ["./", $home_kiro]
      },
      write: {
        allowedPaths: ["./.plan"]
      },
    },
    resources: [
      "skill://.kiro/skills/*/SKILL.md",
      $skills,
      $grill,
      "file://.kiro/steering/*.md"
    ],
    prompt: $prompt
  }' > "$AGENTS_DIR/planner.json"
inject_planner_plan_write_hook "$AGENTS_DIR/planner.json"
inject_planner_task_markdown_hook "$AGENTS_DIR/planner.json"
inject_caveman_hook "$AGENTS_DIR/planner.json"
inject_locale_hook "$AGENTS_DIR/planner.json"

# --- code_supervisor ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/code_supervisor.md" \
  --arg skills "$KIRO_SKILLS_URI" \
  --arg notify "${HOME_DIR}/.kiro/hooks/code_supervisor/cmux-notify.sh" \
  --arg phase_reminder "$KIRO_DIR/hooks/code_supervisor/phase-reminder.sh" \
  --arg validate_write "${HOME_DIR}/.kiro/hooks/code_supervisor/validate-supervisor-plan-write.js" \
  --arg validate_read "${HOME_DIR}/.kiro/hooks/code_supervisor/validate-read-allowed-paths.js" \
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "code_supervisor",
    prompt: $prompt,
    model: "claude-opus-4.6",
    description: "Coding Supervisor Agent that orchestrates and delegates tasks to specialized agents",
    tools: ["read", "write", "subagent", "todo", "thinking", "introspect", "session", "shell", "@git"],
    allowedTools: ["subagent", "todo", "thinking", "introspect", "session", "@git"],
    useLegacyMcpJson: false,
    toolsSettings: {
      shell: {
        allowedCommands: ["rkt cmux .*"],
        denyByDefault: true
      },
      write: {
        allowedPaths: ["./.plan"]
      },
      read: {
        allowedPaths: ["./.plan", "/var/folders", "/private/var/folders", $home_kiro]
      },
      subagent: {
        availableAgents: ["planner", "designer", "developer", "explorer", "reviewer", "simplifier", "tester", "debugger", "councillor-a", "councillor-b", "councillor-c", "council-master"],
        trustedAgents: ["planner", "designer", "developer", "explorer", "reviewer", "simplifier", "tester", "debugger", "councillor-a", "councillor-b", "councillor-c", "council-master"]
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
          command: $notify
        }
      ],
      userPromptSubmit: [
        {
          command: $phase_reminder
        }
      ],
      preToolUse: [
        {
          command: $validate_read,
          matcher: "read"
        },
        {
          command: $validate_write,
          matcher: "write"
        }
      ]
    }
  }' > "$AGENTS_DIR/code_supervisor.json"
inject_caveman_hook "$AGENTS_DIR/code_supervisor.json"
inject_locale_hook "$AGENTS_DIR/code_supervisor.json"

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
    welcomeMessage: "What research topic or paper are you looking for?",
    resources: [$exa_skill],
    mcpServers: {
      exa: {
        type: "remote",
        url: "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa",
        headers: {
          "x-api-key": $exa_key
        }
      }
    },
    prompt: $prompt
  }' > "$AGENTS_DIR/researcher.json"
inject_caveman_hook "$AGENTS_DIR/researcher.json"
inject_locale_hook "$AGENTS_DIR/researcher.json"

# --- councillor-a (Claude Opus) ---
jq -n \
  --arg prompt "file://${HOME_DIR}/.kiro/agents/councillor-a.md" \
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "councillor-a",
    description: "Council advisor (Opus). Read-only codebase analysis for multi-model consensus.",
    model: "claude-opus-4.6",
    tools: ["read", "grep", "glob"],
    allowedTools: ["read", "grep", "glob"],
    useLegacyMcpJson: false,
    toolsSettings: {
      read: { allowedPaths: ["./", $home_kiro] },
      grep: { allowedPaths: ["./"] },
      glob: { allowedPaths: ["./"] }
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
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "councillor-b",
    description: "Council advisor (Sonnet). Read-only codebase analysis for multi-model consensus.",
    model: "glm-5",
    tools: ["read", "grep", "glob"],
    allowedTools: ["read", "grep", "glob"],
    useLegacyMcpJson: false,
    toolsSettings: {
      read: { allowedPaths: ["./", $home_kiro] },
      grep: { allowedPaths: ["./"] },
      glob: { allowedPaths: ["./"] }
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
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "councillor-c",
    description: "Council advisor. Read-only codebase analysis for multi-model consensus.",
    model: "claude-opus-4.5",
    tools: ["read", "grep", "glob"],
    allowedTools: ["read", "grep", "glob"],
    useLegacyMcpJson: false,
    toolsSettings: {
      read: { allowedPaths: ["./", $home_kiro] },
      grep: { allowedPaths: ["./"] },
      glob: { allowedPaths: ["./"] }
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
  --arg home_kiro "${HOME_DIR}/.kiro" \
  '{
    name: "council-master",
    description: "Council synthesis engine. Reviews councillor responses and produces the final answer.",
    model: "claude-opus-4.6",
    tools: ["read", "grep", "glob"],
    allowedTools: ["read", "grep", "glob"],
    useLegacyMcpJson: false,
    toolsSettings: {
      read: { allowedPaths: ["./", $home_kiro] },
      grep: { allowedPaths: ["./"] },
      glob: { allowedPaths: ["./"] }
    },
    prompt: $prompt
  }' > "$AGENTS_DIR/council-master.json"
inject_caveman_hook "$AGENTS_DIR/council-master.json"
inject_locale_hook "$AGENTS_DIR/council-master.json"

# --- mcp.json ---
jq -n \
  --arg exa_key "${EXA_API_KEY}" \
  --arg kiro_executor "${KIRO_DIR}/mcp/kiro-executor/server.mjs" \
  '{
    mcpServers: {
      git: { command: "uvx", args: ["mcp-server-git"], env: { GIT_CONFIG_GLOBAL: "/dev/null" } },
      context7: { command: "npx", args: ["-y", "@upstash/context7-mcp"] },
      "chrome-devtools": { command: "npx", args: ["-y", "chrome-devtools-mcp@latest"], autoApprove: ["take_screenshot", "list_pages"], disabled: true },
      "figma-developer-mcp": { command: "npx", args: ["-y", "figma-developer-mcp", "--stdio"] },
      exa: {
        type: "remote",
        url: "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa",
        headers: {
          "x-api-key": $exa_key
        }
      },
      "github-grep": { url: "https://mcp.grep.app" }
    }
  }' > "$KIRO_DIR/settings/mcp.json"

# --- Summary ---
echo ""
echo "Kiro configuration complete:"
echo "  Agents:"
for f in developer reviewer designer explorer simplifier tester debugger planner code_supervisor researcher councillor-a councillor-b councillor-c council-master; do
  echo "    ✓ $AGENTS_DIR/$f.json"
done
echo "  Settings:"
echo "    ✓ $KIRO_DIR/settings/mcp.json"
echo "  Hooks (managed separately in hooks/):"
for f in caveman.sh locale.sh code_supervisor/phase-reminder.sh code_supervisor/cmux-notify.sh code_supervisor/validate-read-allowed-paths.js code_supervisor/validate-supervisor-plan-write.js planner/validate-planner-plan-write.js plan_writers/validate-artifact-plan-write.js source_writing/validate-developer-plan.js shell/rtk-rewrite.js shell/rtk-rules.sh shell/validate-local-rm.js; do
  if [ -f "$KIRO_DIR/hooks/$f" ]; then
    echo "    ✓ $KIRO_DIR/hooks/$f"
  else
    echo "    ⚠ $KIRO_DIR/hooks/$f not found"
  fi
done
echo ""
echo "Note: .md prompt files and SKILL.md files are NOT generated by this script."
