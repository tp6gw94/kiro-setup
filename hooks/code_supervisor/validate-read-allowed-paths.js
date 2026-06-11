#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");

function readStdin() {
  return fs.readFileSync(0, "utf8");
}

function parsePayload(input) {
  try {
    return JSON.parse(input || "{}");
  } catch (_err) {
    return {};
  }
}

// Resolve `~`, make absolute, and collapse `..`/`.` WITHOUT following
// symlinks. Following symlinks (realpath) wrongly rejected legitimate paths
// such as ~/.kiro/skills/<name> when those entries are symlinks pointing
// outside the allowed root (e.g. into ~/.agents/skills).
function normalizePath(base, value) {
  const expanded =
    value === "~" || value.startsWith(`~${path.sep}`)
      ? path.join(os.homedir(), value.slice(1))
      : value;
  const absolute = path.isAbsolute(expanded) ? expanded : path.resolve(base, expanded);
  return path.resolve(absolute);
}

function log(message) {
  try {
    if (process.env.KIRO_VALIDATE_READ_LOG === "0") return;
    const logDir = path.join(os.homedir(), ".kiro", "logs");
    fs.mkdirSync(logDir, { recursive: true });
    const line = `${new Date().toISOString()} ${message}\n`;
    fs.appendFileSync(path.join(logDir, "validate-read-allowed-paths.log"), line);
  } catch (_err) {
    // logging must never break the hook
  }
}

function isUnderOrEqual(candidate, root) {
  if (candidate === root) return true;
  const relative = path.relative(root, candidate);
  return relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative);
}

function block(message) {
  console.error(message);
  process.exit(2);
}

const payload = parsePayload(readStdin());
const cwd = payload.cwd || process.cwd();
const kiroHome = process.env.KIRO_HOME || path.join(os.homedir(), ".kiro");

const paths = [];
const toolInput = payload.tool_input || {};
if (typeof toolInput.path === "string" && toolInput.path.length > 0) {
  paths.push(toolInput.path);
}
if (Array.isArray(toolInput.operations)) {
  for (const operation of toolInput.operations) {
    if (typeof operation?.path === "string" && operation.path.length > 0) {
      paths.push(operation.path);
    }
  }
}

if (paths.length === 0) {
  block(
    "BLOCKED: Could not determine read path from tool input.\n" +
      "Expected .tool_input.path or .tool_input.operations[].path."
  );
}

const allowedRoots = [
  normalizePath(cwd, ".plan"),
  normalizePath(cwd, kiroHome),
  normalizePath(cwd, "/var/folders"),
  normalizePath(cwd, "/private/var/folders"),
];

log(`cwd=${cwd} roots=${JSON.stringify(allowedRoots)} paths=${JSON.stringify(paths)}`);

for (const requestedPath of paths) {
  const normalized = normalizePath(cwd, requestedPath);
  if (allowedRoots.some((root) => isUnderOrEqual(normalized, root))) {
    log(`ALLOW '${requestedPath}' -> '${normalized}'`);
    continue;
  }

  log(`BLOCK '${requestedPath}' -> '${normalized}'`);
  block(
    `BLOCKED: code_supervisor cannot read '${requestedPath}'.\n` +
      "Use explorer subagent to read file"
  );
}
