#!/usr/bin/env node
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

function parsePayload(input) {
  try {
    return JSON.parse(input || "{}");
  } catch (_err) {
    return {};
  }
}

function normalizePath(value) {
  const absolute = path.resolve(value);
  const parts = absolute.split(path.sep);
  for (let i = parts.length; i > 0; i -= 1) {
    const existing = parts.slice(0, i).join(path.sep) || path.sep;
    if (!fs.existsSync(existing)) continue;
    const rest = parts.slice(i);
    return path.normalize(path.join(fs.realpathSync.native(existing), ...rest));
  }
  return path.normalize(absolute);
}

function isDirectPlanTask(candidate, planRoot) {
  const relative = path.relative(planRoot, candidate);
  if (relative === "" || relative.startsWith("..") || path.isAbsolute(relative)) {
    return false;
  }
  const parts = relative.split(path.sep);
  return parts.length === 2 && parts[1] === "task.md";
}

function stateFileFor(sessionId, taskPath) {
  const root = process.env.KIRO_TASK_MARKDOWN_STATE_DIR ||
    path.join(os.tmpdir(), "kiro-open-task-markdown");
  const key = crypto
    .createHash("sha256")
    .update(`${sessionId || "unknown"}\0${taskPath}`)
    .digest("hex");
  return path.join(root, `${key}.opened`);
}

function alreadyOpened(sessionId, taskPath) {
  return fs.existsSync(stateFileFor(sessionId, taskPath));
}

function markOpened(sessionId, taskPath) {
  const marker = stateFileFor(sessionId, taskPath);
  fs.mkdirSync(path.dirname(marker), { recursive: true });
  fs.writeFileSync(marker, new Date().toISOString());
}

function cmuxAvailable() {
  const ping = spawnSync("cmux", ["ping"], { stdio: "ignore" });
  return ping.status === 0;
}

function openMarkdown(taskPath) {
  spawnSync("cmux", ["markdown", "open", taskPath], { stdio: "ignore" });
}

const payload = parsePayload(fs.readFileSync(0, "utf8"));

if (payload.hook_event_name && payload.hook_event_name !== "postToolUse") {
  process.exit(0);
}

if (payload.tool_name !== "write") {
  process.exit(0);
}

if (payload.tool_response?.success !== true) {
  process.exit(0);
}

const requestedPath = payload.tool_input?.path;
if (typeof requestedPath !== "string" || requestedPath.length === 0) {
  process.exit(0);
}

const cwd = payload.cwd || process.cwd();
const absolutePath = path.isAbsolute(requestedPath)
  ? normalizePath(requestedPath)
  : normalizePath(path.join(cwd, requestedPath));
const planRoot = normalizePath(path.join(cwd, ".plan"));

if (!isDirectPlanTask(absolutePath, planRoot)) {
  process.exit(0);
}

try {
  if (alreadyOpened(payload.session_id, absolutePath)) {
    process.exit(0);
  }
  if (!cmuxAvailable()) {
    process.exit(0);
  }
  markOpened(payload.session_id, absolutePath);
  openMarkdown(absolutePath);
} catch (_err) {
  process.exit(0);
}
