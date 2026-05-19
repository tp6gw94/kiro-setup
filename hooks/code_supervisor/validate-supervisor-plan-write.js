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

function extractWriteContent(payload, absolutePath) {
  const input = payload.tool_input || {};
  for (const key of ["content", "text", "file_text", "data", "value"]) {
    if (typeof input[key] === "string") return input[key];
  }
  if (fs.existsSync(absolutePath)) return fs.readFileSync(absolutePath, "utf8");
  return "";
}

function activePlanFromContent(content, repoRoot, planRoot) {
  let activePlan = content.split(/\r?\n/, 1)[0].replace(/\r/g, "").trim();
  if (!activePlan) {
    block("BLOCKED: Could not determine active developer plan path from write content.");
  }
  if (!path.isAbsolute(activePlan)) {
    activePlan = activePlan.startsWith(".plan/")
      ? path.join(repoRoot, activePlan)
      : path.join(planRoot, activePlan);
  }
  return normalizePath(activePlan);
}

function validatePlannerReadyPlan(activePlan, planRoot) {
  if (path.dirname(activePlan) !== planRoot) {
    block(`BLOCKED: Active developer plan must point inside .plan as a direct task folder: ${activePlan}`);
  }

  const taskFile = path.join(activePlan, "task.md");
  const questionsFile = path.join(activePlan, "questions.md");
  const markerFile = path.join(activePlan, ".planner-ready.json");

  if (!fs.existsSync(taskFile)) {
    block(`BLOCKED: task.md was not found at ${taskFile}. Delegate planner before activating this plan.`);
  }
  if (!fs.existsSync(questionsFile)) {
    block(`BLOCKED: questions.md was not found at ${questionsFile}. Delegate planner before activating this plan.`);
  }
  if (fs.readFileSync(questionsFile, "utf8").trim() !== "NO_QUESTIONS") {
    block("BLOCKED: Active developer plan requires questions.md to be exactly NO_QUESTIONS.");
  }
  if (!fs.existsSync(markerFile)) {
    block(`BLOCKED: ${markerFile} was not found. Delegate planner to mark this plan ready before activation.`);
  }
}

const payload = parsePayload(fs.readFileSync(0, "utf8"));
const requestedPath = payload.tool_input?.path;
const cwd = payload.cwd || process.cwd();

if (typeof requestedPath !== "string" || requestedPath.length === 0) {
  block("BLOCKED: code_supervisor cannot write to an unknown path.");
}

const repoRoot = normalizePath(cwd);
const planRoot = normalizePath(path.join(repoRoot, ".plan"));
const absolutePath = path.isAbsolute(requestedPath)
  ? normalizePath(requestedPath)
  : normalizePath(path.join(repoRoot, requestedPath));

if (!isUnderOrEqual(absolutePath, planRoot)) {
  block(`BLOCKED: code_supervisor cannot write to '${absolutePath}'. Only .plan/ is writable.`);
}

const relative = path.relative(planRoot, absolutePath);
const parts = relative.split(path.sep);
const filename = parts[parts.length - 1];

if (parts.length === 2 && ["task.md", "questions.md", ".planner-ready.json"].includes(filename)) {
  block(`BLOCKED: ${filename} is planner-owned. Delegate planner instead of writing it from code_supervisor.`);
}

if (relative === ".active-developer-plan") {
  const content = extractWriteContent(payload, absolutePath);
  const activePlan = activePlanFromContent(content, repoRoot, planRoot);
  validatePlannerReadyPlan(activePlan, planRoot);
}
