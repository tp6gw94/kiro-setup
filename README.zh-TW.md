# Kiro CLI 設定檔

基於 Kiro CLI 的多代理 AI 編碼協調器。包含 15 個專業代理、6 個自訂 Hook、24 個技能，以及程式碼生成設定管線。

所有代理設定（`.json`）皆由 `generate-configs.sh` 在執行時產生，不納入版本控制。Prompt 檔案（`.md`）與 Hook 腳本（`.sh`）才是 Git 追蹤的真實來源。

---

## 目錄

- [架構概覽](#架構概覽)
- [快速開始](#快速開始)
- [代理列表](#代理列表)
- [Hooks](#hooks)
- [RTK 整合](#rtk-整合)
- [技能](#技能)
- [cmux 整合](#cmux-整合)
- [MCP 伺服器](#mcp-伺服器)
- [設定管線](#設定管線)
- [Plan 資料夾協議](#plan-資料夾協議)
- [設定值](#設定值)
- [設計模式](#設計模式)

---

## 架構概覽

```
使用者
  │
  ▼
code_supervisor（ctrl+a）── 協調器，僅持有 read / subagent / todo / thinking 工具
  │
  ├─ 10 個 leaf agent（各自擁有完整工具鏈）
  │   developer · reviewer · designer · explorer · simplifier
  │   tester · debugger · planner · librarian · researcher
  │
  └─ 4 個 council agent（唯讀，用於多模型共識）
      councillor-a (Opus 4.6) · councillor-b (GLM-5) · councillor-c (Opus 4.5)
      council-master (Opus 4.6)
```

核心設計：

- `code_supervisor` 是唯一的進入點，透過 `use_subagent` 工具將任務委派給專職代理
- Leaf agent 各自擁有獨立的工具權限與 MCP 伺服器存取
- Council agent 為唯讀模式（禁止寫入檔案與執行指令），專門用於架構決策的多模型共識
- 所有 prompt 採用 XML tag 格式撰寫

---

## 快速開始

### 前置需求

| 工具 | 用途 |
|------|------|
| `jq` | JSON 處理，設定生成必備 |
| Node.js（`npx`） | Context7、Figma MCP 伺服器 |
| Python 3（`uvx`） | Git MCP 伺服器 |
| `EXA_API_KEY` 環境變數 | Exa 搜尋 API |
| `rtk`（Rust Token Killer） | 用於 token 優化的 shell 指令執行。安裝來源：[rtk-ai/rtk](https://github.com/rtk-ai/rtk) |
| `cmux`（選用） | 原生 macOS 終端機，專為 AI 編碼代理設計。啟用桌面通知。安裝來源：[manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) |

### 安裝步驟

```bash
# 1. 複製此目錄
cp -r .kiro/ ~/.kiro/

# 2. 設定環境變數
export EXA_API_KEY="your-key-here"

# 3. 生成代理設定
chmod +x ~/.kiro/generate-configs.sh
~/.kiro/generate-configs.sh

# 4. 啟動
kiro-cli chat
```

**自訂語言：** 如需更改回應語言，請編輯 `hooks/locale.sh`。預設為繁體中文（Traditional Chinese）。

---

### Leaf Agent

| 名稱 | 角色 | 模型 | 快捷鍵 | MCP 伺服器 |
|------|------|------|---------|------------|
| `developer` | 程式碼實作 | claude-opus-4.6 | `ctrl+shift+d` | — |
| `reviewer` | 程式碼審查 & YAGNI 把關 | claude-opus-4.6 | `ctrl+r` | — |
| `designer` | Figma 設計擷取 | claude-opus-4.6 | `ctrl+shift+f` | figma-developer-mcp |
| `explorer` | 程式碼庫調查 & 文件研究 | claude-opus-4.6 | `ctrl+e` | context7, exa, github-grep |
| `simplifier` | 程式碼精煉 & 重構 | claude-opus-4.6 | `ctrl+shift+s` | git |
| `tester` | 測試套件設計 & 覆蓋率分析 | claude-opus-4.6 | `ctrl+t` | — |
| `debugger` | 根因調查 & 問題報告 | claude-opus-4.6 | `ctrl+b` | — |
| `planner` | 結構化執行計畫 | claude-opus-4.6 | `ctrl+p` | — |
| `librarian` | 函式庫文件 & API 研究 | claude-opus-4.6 | `ctrl+l` | context7, exa, github-grep |
| `researcher` | 學術論文搜尋 & 分析 | claude-opus-4.6 | `ctrl+shift+r` | exa |

### 協調器

| 名稱 | 角色 | 模型 | 快捷鍵 |
|------|------|------|---------|
| `code_supervisor` | 任務協調 & 委派 | claude-opus-4.6 | `ctrl+a` |

`code_supervisor` 僅持有精簡工具集（`read`、`use_subagent`、`todo`、`thinking`、`introspect`、`session`），強制透過委派完成所有實作工作。

### Council Agent

| 名稱 | 角色 | 模型 |
|------|------|------|
| `councillor-a` | 顧問（觀點 A） | claude-opus-4.6 |
| `councillor-b` | 顧問（觀點 B） | glm-5 |
| `councillor-c` | 顧問（觀點 C） | claude-opus-4.5 |
| `council-master` | 共識綜合引擎 | claude-opus-4.6 |

Council 流程：三位顧問各自獨立分析同一問題，`council-master` 彙整三方觀點後產出最終建議。所有 council agent 皆為唯讀模式。

---

## Hooks

本設定使用 6 個自訂 Hook，透過不同觸發時機注入行為：

| Hook | 觸發時機 | 適用範圍 | 說明 |
|------|----------|----------|------|
| `rtk-rewrite.sh` | `preToolUse`（shell） | 大部分 leaf agent | 攔截 shell 指令，透過 RTK 重寫以節省 token |
| `rtk-rules.sh` | `agentSpawn` | 大部分 leaf agent | 啟動時注入 RTK 使用說明（加 `rtk` 前綴） |
| `caveman.sh` | `agentSpawn` | 所有代理 | 注入原始人說話風格 |
| `locale.sh` | `agentSpawn` | 所有代理 | 注入繁體中文語系指令 |
| `phase-reminder.sh` | `userPromptSubmit` | `code_supervisor` | 提醒協調器遵循 6 階段工作流程 |
| `cmux-notify.sh` | `stop` | `code_supervisor` | 回應完成時透過 cmux 發送桌面通知 |

### Hook 注入邏輯

`generate-configs.sh` 中定義了四個注入函式，在生成每個代理的 JSON 設定時依序呼叫：

- `inject_rtk_hook` — 加入 `preToolUse` hook（匹配 `execute_bash`）
- `inject_rtk_spawn_hook` — 加入 `agentSpawn` hook（RTK 規則）
- `inject_caveman_hook` — 加入 `agentSpawn` hook（原始人風格）
- `inject_locale_hook` — 加入 `agentSpawn` hook（繁體中文）

注意：`planner`、`code_supervisor`、`librarian`、`researcher` 及所有 council agent 不注入 RTK hook（因為它們不直接執行 shell 指令或有其他考量）。

---

## RTK 整合

RTK（Rust Token Killer）是一個 CLI 代理工具，能壓縮 shell 指令的輸出以節省 token 用量。

### 雙層保護機制

1. **`agentSpawn` hook（`rtk-rules.sh`）**：代理啟動時注入提示，告知代理所有 shell 指令都應加上 `rtk` 前綴
2. **`preToolUse` hook（`rtk-rewrite.sh`）**：攔截實際的 shell 呼叫，透過 `rtk rewrite` 自動重寫指令

### 為什麼需要兩層？

`agentSpawn` hook 只在代理首次啟動時觸發，不會在 subagent session 中再次觸發。但 `preToolUse` hook 會在每次工具呼叫時觸發，確保即使代理忘記加 `rtk` 前綴，指令仍會被自動重寫。

### 容錯設計

- 若 `rtk` 未安裝或版本低於 0.23.0，hook 會靜默跳過
- 若 `jq` 未安裝，同樣靜默跳過
- 版本檢查結果會快取至 `~/.cache/rtk-hook-version-ok`

---

## 技能

### 本地技能

| 技能 | 說明 |
|------|------|
| `cartography` | 為陌生程式碼庫生成階層式 codemap |
| `council-session` | 多模型共識決策流程 |
| `simplifier` | 程式碼精煉與簡化指引 |
| `get-code-context-exa` | 透過 Exa 搜尋程式碼範例與文件 |
| `web-search-advanced-research-paper-exa` | 透過 Exa 搜尋學術論文 |

### Caveman

[Caveman](https://github.com/juliusbrussee/caveman) — 減少約 75% 輸出 token，同時保持技術準確性。包含 5 個子技能（caveman、caveman-commit、caveman-compress、caveman-help、caveman-review）。強度等級：`lite`、`full`（預設）、`ultra`。也透過 `hooks/caveman.sh`（`agentSpawn`）注入以實現常駐模式。

### Grill Me

[Grill Me](https://github.com/mattpocock/skills/blob/main/grill-me/SKILL.md) — 對計畫或設計進行壓力測試式提問，逐一走過設計決策樹的每個分支，直到達成共識。

> **更多技能：** 可透過 [vercel-labs/skills](https://github.com/vercel-labs/skills) 安裝更多技能。

---

## cmux 整合

[cmux](https://github.com/manaflow-ai/cmux) 是一款基於 Ghostty（libghostty）的原生 macOS 終端機應用程式，專為同時運行多個 AI 編碼代理的開發者設計。提供通知環、工作區管理，以及可腳本化的 CLI — 專為代理工作流程打造。

### 安裝方式

**Homebrew：**
```bash
brew tap manaflow-ai/cmux
brew install --cask cmux
```

**或下載 DMG：** [cmux-macos.dmg](https://github.com/manaflow-ai/cmux/releases/latest/download/cmux-macos.dmg)

**CLI 設定**（在 cmux 終端機外使用）：
```bash
sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux
```

### 在本設定中的用途

`cmux-notify.sh` hook（在 `code_supervisor` 的 `stop` 事件觸發）會在協調器完成回應時透過 `cmux notify` 發送桌面通知。cmux 側邊欄的分頁會亮起藍色通知環，顯示專案名稱與回應預覽 — 在跨工作區管理多個 Kiro CLI 會話時非常實用。

此 hook 包含防護條件（`cmux ping || exit 0`），若 cmux 未安裝或未運行，會靜默跳過不執行。

---

## MCP 伺服器

| 伺服器 | 類型 | 指令 / URL | 用途 |
|--------|------|-----------|------|
| `git` | stdio | `uvx mcp-server-git` | Git 操作 |
| `context7` | stdio | `npx -y @upstash/context7-mcp` | 函式庫文件查詢 |
| `figma-developer-mcp` | stdio | `npx -y figma-developer-mcp --stdio` | Figma 設計擷取 |
| [`exa`](https://github.com/exa-labs/exa-mcp-server) | remote | `https://mcp.exa.ai/mcp?exaApiKey=...` | 網路搜尋 & 學術論文 |
| `github-grep` | remote | `https://mcp.grep.app` | GitHub 程式碼搜尋 |
| `chrome-devtools` | stdio | `npx -y chrome-devtools-mcp@latest` | 瀏覽器除錯（預設停用） |

各代理僅掛載所需的 MCP 伺服器，而非全部共用。例如 `designer` 只掛載 `figma-developer-mcp`，`researcher` 只掛載 `exa`。

---

## 設定管線

```
generate-configs.sh（唯一真實來源）
  │
  ├─ 讀取 .md prompt 檔案（Git 追蹤）
  ├─ 讀取 .sh hook 腳本（Git 追蹤）
  ├─ 讀取 EXA_API_KEY 環境變數
  │
  └─ 產生 ─┬─ agents/*.json（gitignore）
            └─ settings/mcp.json（gitignore）
```

---

## Plan 資料夾協議

`.plan/<task-name>/` 是代理間的通訊目錄，用於在協調器與各專職代理之間傳遞結構化資訊。

### 標準化檔名

| 檔名 | 產出者 | 說明 |
|------|--------|------|
| `task.md` | planner | 完整的任務需求描述 |
| `exploration-brief.md` | explorer | 程式碼庫架構、慣例、函式庫用法 |
| `design-spec.md` | designer | UI 設計規格（含 Figma 擷取） |
| `dev-notes.md` | developer | 實作筆記、決策紀錄、變更檔案清單 |
| `review.md` | reviewer | 程式碼審查結果 |
| `simplifier-notes.md` | simplifier | 精煉建議與變更紀錄 |
| `questions.md` | planner | 需要使用者釐清的問題 |
| `answers.md` | 使用者/supervisor | 對問題的回覆 |
| `assets/` | designer | 下載的圖片、SVG 等設計素材 |

### 工作流程範例

```
supervisor 建立 .plan/my-feature/
  → planner 寫入 task.md
  → explorer 寫入 exploration-brief.md
  → developer 讀取上述檔案，實作後寫入 dev-notes.md
  → reviewer 讀取 dev-notes.md，審查後寫入 review.md
```

---

## 設定值

`settings/cli.json` 中的關鍵設定：

| 設定項 | 值 | 說明 |
|--------|-----|------|
| `chat.defaultAgent` | `code_supervisor` | 預設啟動的代理 |
| `chat.defaultModel` | `claude-opus4.6` | 預設語言模型 |
| `chat.enableThinking` | `true` | 啟用思考模式 |
| `chat.enableTangentMode` | `true` | 啟用切線模式 |
| `chat.enableTodoList` | `true` | 啟用待辦清單 |
| `chat.greeting.enabled` | `false` | 停用開場問候 |
| `chat.diffTool` | `delta --side-by-side --paging=never` | 差異比對工具 |

---

## 設計模式

本設定體現了以下設計理念：

### 1. 程式碼生成優於手動設定

所有 `.json` 代理設定皆由 `generate-configs.sh` 生成，避免手動維護多份設定檔的同步問題。修改一處腳本即可影響所有代理。

### 2. Hook 注入模式

透過 `agentSpawn`、`preToolUse`、`postToolUse`、`userPromptSubmit`、`stop` 等觸發點，在不修改代理 prompt 的前提下注入額外行為（語系、風格、工具重寫等）。

### 3. 關注點分離

每個代理只負責一件事。`code_supervisor` 不寫程式碼，`developer` 不做審查，`reviewer` 不做實作。工具權限也嚴格限縮。

### 4. Plan 資料夾協議

代理之間不直接對話，而是透過 `.plan/` 目錄中的標準化檔案進行非同步通訊，確保資訊可追溯、可重播。

### 5. 平行波次執行

`code_supervisor` 的 6 階段工作流程（理解 → 路徑選擇 → 委派檢查 → 拆分並行 → 執行 → 驗證）支援在同一輪次中平行啟動多個獨立的 subagent。

### 6. 多模型共識

透過 council 機制，讓不同模型（Opus 4.6、GLM-5、Opus 4.5）各自獨立分析同一問題，再由 `council-master` 綜合出最終建議，降低單一模型偏見。
