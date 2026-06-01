# Kiro CLI 設定檔

這是個人使用的 Kiro CLI 多代理編碼工作流設定。目前生成出的執行期設定包含 14 個代理、13 個 runtime hook、10 個 Git 追蹤的本地技能，以及一組用於搜尋、Git、瀏覽器、Figma 與本地檔案操作的 MCP 伺服器。

此目錄中的 markdown、hook、skill 與腳本才是真實來源；生成出的 JSON 設定不納入版本控制。

## 快速開始

### 前置需求

| 需求 | 用途 |
|------|------|
| `jq` | 生成 JSON 設定 |
| Node.js / `npx` | 執行 Context7、Figma 與選用的 Chrome DevTools MCP |
| Python 3 / `uvx` | 執行 Git MCP |
| `EXA_API_KEY` | 啟用 Exa 搜尋 MCP |
| `rtk` | token 優化的 shell 指令代理 |
| `cmux` | 選用的桌面通知與 markdown 預覽面板 |

### 安裝

```bash
cp -r .kiro ~/.kiro
export EXA_API_KEY="your-key-here"
chmod +x ~/.kiro/generate-configs.sh
~/.kiro/generate-configs.sh
kiro-cli chat
```

預設回應語言是繁體中文；可在 `hooks/locale.sh` 修改。

### Docker Sandbox 設定

`kits/kiro-sandbox` 是此 repo 的本機 Docker Sandbox kit。它是
`kind: mixin`，會 extend 內建的 `kiro` agent、開放 sandbox 網路存取，並設定
global Kiro config 需要的 runtime `PATH`/`PNPM_HOME`。

先用 `Dockerfile.kiro-sandbox` 建立 custom Kiro template，再載入 kit 執行
Kiro：

```bash
./build-kiro-sandbox-template.sh kiro-sandbox-template:v1
docker image save kiro-sandbox-template:v1 -o kiro-sandbox-template.tar
sbx template load kiro-sandbox-template.tar
sbx run -t kiro-sandbox-template:v1 --kit ./kits/kiro-sandbox kiro
```

build script 會執行 `sync-kit-skills.sh`，把 symlink skills 展開到 kit 的
`files/home/.kiro/skills`，建立暫時 Docker build context，並將
`kits/kiro-sandbox/files/home/.kiro` 複製進 image 的 `/home/agent/.kiro`。這個
template 會 extend `docker/sandbox-templates:kiro-docker`、安裝 Node.js 24、pnpm、
Playwright、RTK 與 uv、設定 Git identity/default branch 預設值，並將 global
Kiro 設定 bake 到 `/home/agent/.kiro`。

如果 sandbox 建立後需要 host credentials，可將支援的環境變數注入 sandbox 的
persistent shell profile：

```bash
kits/kiro-sandbox/inject-env.sh <sandbox-name>
```

`inject-env.sh` 目前會持久化 `EXA_API_KEY` 與 `FIGMA_API_KEY`。

## 架構

```text
user
  |
  v
code_supervisor
  |-- leaf agents: developer, reviewer, designer, explorer, simplifier,
  |   tester, debugger, planner, researcher
  |
  |-- council agents: councillor-a, councillor-b, councillor-c, council-master
  |
  `-- .plan/<task>/ artifacts 作為代理間交接資料
```

核心規則：

- `generate-configs.sh` 生成 `agents/*.json` 與 `settings/mcp.json`。
- `sync-kit-skills.sh` 將本機 skills 複製到 Kiro sandbox kit，並把 symlink 展開成實體目錄。
- `build-kiro-sandbox-template.sh` 建立包含 RTK、Git config 與 generated `~/.kiro` 的 Kiro Docker Sandbox template。
- 代理 prompt 放在 `agents/*.md`。
- Hook 腳本放在 `hooks/`。
- 技能放在 `skills/*/SKILL.md`。
- `.plan/<task>/` 是委派工作的協調層。

## 代理

### Leaf Agents

| 代理 | 角色 | 模型 | 快捷鍵 | MCP |
|------|------|------|--------|-----|
| `developer` | 程式碼實作 | `claude-opus-4.7` | `ctrl+shift+d` | `local-fs` |
| `reviewer` | 程式碼審查與 YAGNI 把關 | `claude-opus-4.7` | `ctrl+r` | - |
| `designer` | Figma 設計擷取 | `claude-opus-4.7` | `ctrl+shift+f` | `figma-developer-mcp` |
| `explorer` | 程式碼庫與文件研究 | `claude-sonnet-4.6` | `ctrl+e` | `context7`, `exa`, `github-grep` |
| `simplifier` | 程式碼精煉 | `claude-opus-4.7` | `ctrl+shift+s` | `git` |
| `tester` | 驗證證據與風險分析 | `claude-opus-4.7` | `ctrl+t` | - |
| `debugger` | 根因調查 | `claude-opus-4.7` | `ctrl+b` | - |
| `planner` | 結構化執行計畫 | `claude-opus-4.7` | `ctrl+p` | - |
| `researcher` | 網路與論文研究 | `claude-opus-4.7` | `ctrl+shift+r` | `exa` |
| `ralph` | Sandbox YOLO 實作迴圈 | `claude-opus-4.8` | - | 所有 MCP servers |

### Supervisor

| 代理 | 角色 | 模型 | 快捷鍵 | MCP |
|------|------|------|--------|-----|
| `code_supervisor` | 委派任務並驗證 `.plan` artifacts | `claude-opus-4.7` | `ctrl+a` | `git`, `local-fs` |

### Council

| 代理 | 角色 | 模型 |
|------|------|------|
| `councillor-a` | 唯讀獨立顧問 | `claude-opus-4.7` |
| `councillor-b` | 唯讀獨立顧問 | `glm-5` |
| `councillor-c` | 唯讀獨立顧問 | `deepseek-3.2` |
| `council-master` | 彙整 council 共識 | `claude-opus-4.7` |

## Hooks

Runtime hooks 由 `generate-configs.sh` 注入；`hooks/test-*` 是測試檔，不算 runtime hook。

| Hook | 觸發時機 | 範圍 | 用途 |
|------|----------|------|------|
| `shell/rtk-rewrite.js` | `preToolUse` | 可用 shell 的代理 | 將 shell 指令改寫為 RTK 形式 |
| `shell/rtk-rules.sh` | `agentSpawn` | 可用 shell 的代理 | 啟動時注入 RTK 使用規則 |
| `shell/validate-local-rm.js` | `preToolUse` | `developer` | 阻擋目前工作目錄外的危險 `rm` |
| `caveman.sh` | `agentSpawn` | 所有代理 | 注入精簡回應風格 |
| `locale.sh` | `agentSpawn` | 所有代理 | 注入繁體中文語系 |
| `code_supervisor/phase-reminder.sh` | `userPromptSubmit` | `code_supervisor` | 強制執行委派工作流 |
| `code_supervisor/cmux-notify.sh` | `stop` | `code_supervisor` | 發送 cmux 桌面通知 |
| `code_supervisor/validate-read-allowed-paths.js` | `preToolUse` | `code_supervisor` | 限制 supervisor 可讀路徑 |
| `code_supervisor/validate-supervisor-plan-write.js` | `preToolUse` | `code_supervisor` | 保護 planner-owned plan 檔案 |
| `planner/validate-planner-plan-write.js` | `preToolUse` | `planner` | 限制正式 plan 寫入 |
| `planner/open-task-markdown.js` | `postToolUse` | `planner` | 用 cmux 開啟新的 task markdown |
| `plan_writers/validate-artifact-plan-write.js` | `preToolUse` | `.plan` writers | 限制 artifact 只能寫入 `.plan/` |
| `source_writing/validate-developer-plan.js` | `preToolUse` | source-writing agents | 寫入前要求 active planner-ready task |

## RTK

可用 shell 的代理都需要 RTK。這裡有兩層保護：

1. `shell/rtk-rules.sh` 要求代理在 shell 指令前加上 `rtk`。
2. `shell/rtk-rewrite.js` 攔截 shell tool call，補上遺漏的前綴。

如果 RTK 不存在或版本太舊，hook 會靜默略過。

## 技能

Git 追蹤的本地技能：

| 技能 | 用途 |
|------|------|
| `cartography` | 生成 repository codemap |
| `cmux` | 管理 cmux 視窗、workspace、pane 與焦點 |
| `cmux-browser` | 透過 cmux 做瀏覽器自動化 |
| `cmux-debug-windows` | 管理 cmux debug 視窗與快照 |
| `cmux-markdown` | 在 cmux 中開啟支援 live reload 的 markdown |
| `council-session` | 多模型共識工作流 |
| `debug-hypothesis` | 假設驅動除錯 |
| `get-code-context-exa` | 透過 Exa 搜尋程式碼脈絡 |
| `supervisor-workflow` | Supervisor 委派工作流 |
| `web-search-advanced-research-paper-exa` | 透過 Exa 搜尋研究論文 |

部分本地 skill 目錄可能是指向 `~/.agents/skills` 的 symlink；它們和上方 Git 追蹤的 skill set 分開管理。

## MCP 伺服器

`generate-configs.sh` 會寫出包含以下伺服器的 `settings/mcp.json`：

| 伺服器 | Transport | 用途 |
|--------|-----------|------|
| `git` | `uvx mcp-server-git` | Git 操作，並隔離 global config |
| `context7` | `npx -y @upstash/context7-mcp` | 函式庫文件查詢 |
| `local-fs` | `node ~/.kiro/mcp/local-fs/server.mjs` | 受限的 `rm` 與 `mkdir` helper |
| `chrome-devtools` | `npx -y chrome-devtools-mcp@latest` | 瀏覽器除錯，預設停用 |
| `figma-developer-mcp` | `npx -y figma-developer-mcp --stdio` | Figma 設計擷取 |
| `exa` | Remote MCP | 網路搜尋、fetch 與 advanced search |
| `github-grep` | Remote MCP | GitHub 程式碼搜尋 |

## 設定管線

```text
agents/*.md
hooks/*
skills/*/SKILL.md
mcp/local-fs/server.mjs
        |
        v
generate-configs.sh
        |
        v
agents/*.json
settings/mcp.json
```

生成出的 config 是執行期狀態。需要修改時，請改 markdown prompt、hook 腳本、skill 檔案或 generator script。

## Plan 資料夾協議

`.plan/<task-name>/` 是 supervisor 與 delegated agents 之間的 file-based IPC。

| 檔案 | 擁有者 | 用途 |
|------|--------|------|
| `task.md` | `planner` | 完整任務需求 |
| `questions.md` | `planner` | 釐清問題，或 `NO_QUESTIONS` |
| `.planner-ready.json` | `planner` | plan 已就緒的 marker |
| `answers.md` | 使用者 / supervisor | 使用者對 planner 問題的回答 |
| `exploration-brief.md` | `explorer` | 程式碼庫調查結果 |
| `design-spec.md` | `designer` | UI 設計規格 |
| `dev-notes.md` | `developer` | 實作筆記 |
| `test-notes.md` | `tester` | 驗證證據 |
| `review.md` | `reviewer` | 審查結果 |
| `simplifier-notes.md` | `simplifier` | 精簡與重構筆記 |
| `DEBUG.md` | `debugger` | 除錯假設紀錄 |
| `feedback-investigation.md` | `debugger` | feedback 調查摘要 |
| `assets/` | `designer` | 下載的設計素材 |

## 設計模式

1. 用 code generation 取代手動維護 JSON。
2. 用 runtime hook injection 承載不適合寫進 prompt 的行為。
3. 代理工具權限採最小權限原則。
4. 用 file-based plan artifacts 保留可追蹤的交接紀錄。
5. 對獨立工作做平行委派。
6. 對高風險決策使用多模型 council review。
