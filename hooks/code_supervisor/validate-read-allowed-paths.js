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

function normalizePath(base, value) {
  const absolute = path.isAbsolute(value) ? value : path.resolve(base, value);
  const parts = path.resolve(absolute).split(path.sep);
  for (let i = parts.length; i > 0; i -= 1) {
    const existing = parts.slice(0, i).join(path.sep) || path.sep;
    if (!fs.existsSync(existing)) continue;
    const rest = parts.slice(i);
    return path.join(fs.realpathSync.native(existing), ...rest);
  }
  try {
    return fs.realpathSync.native(absolute);
  } catch (_err) {
    return path.resolve(absolute);
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

for (const requestedPath of paths) {
  const normalized = normalizePath(cwd, requestedPath);
  if (allowedRoots.some((root) => isUnderOrEqual(normalized, root))) {
    continue;
  }

  block(
    `BLOCKED: code_supervisor cannot read '${requestedPath}'.\n` +
      "Use explorer subagent to read file"
  );
}
