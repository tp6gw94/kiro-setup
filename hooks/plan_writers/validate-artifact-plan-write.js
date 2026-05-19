#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

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

function isUnderOrEqual(candidate, root) {
  if (candidate === root) return true;
  const relative = path.relative(root, candidate);
  return relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative);
}

function block(message) {
  console.error(message);
  process.exit(2);
}

const payload = parsePayload(fs.readFileSync(0, "utf8"));
const requestedPath = payload.tool_input?.path;
const cwd = payload.cwd || process.cwd();

if (typeof requestedPath !== "string" || requestedPath.length === 0) {
  block("BLOCKED: artifact writer cannot write to an unknown path.\nOnly .plan/ is writable.");
}

const absolutePath = path.isAbsolute(requestedPath)
  ? normalizePath(requestedPath)
  : normalizePath(path.join(cwd, requestedPath));
const planRoot = normalizePath(path.join(cwd, ".plan"));

if (!isUnderOrEqual(absolutePath, planRoot)) {
  block(`BLOCKED: artifact writer cannot write to '${absolutePath}'.\nOnly .plan/ is writable.`);
}

const relative = path.relative(planRoot, absolutePath);
const parts = relative.split(path.sep);
const filename = parts[parts.length - 1];

if (parts.length === 2 && ["task.md", "questions.md", ".planner-ready.json"].includes(filename)) {
  block(`BLOCKED: ${filename} is planner-owned. Use planner for plan creation or revision.`);
}
