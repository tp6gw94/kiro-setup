#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

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

function block(reason) {
  console.error("BLOCKED: developer requires an approved .plan/<task-name>/task.md before using this tool.");
  console.error(reason);
  process.exit(2);
}

// Consume hook input so callers can pipe payloads exactly as with shell hooks.
try {
  fs.readFileSync(0, "utf8");
} catch (_err) {
  // stdin may be absent in ad-hoc manual runs.
}

const repoRoot = normalizePath(process.env.KIRO_REPO_ROOT || process.cwd());
const planRoot = normalizePath(path.join(repoRoot, ".plan"));
const marker = path.join(planRoot, ".active-developer-plan");

if (!fs.existsSync(marker)) {
  block(`Write the active plan folder path to ${marker} before delegating to developer.`);
}

let activePlan = fs.readFileSync(marker, "utf8").split(/\r?\n/, 1)[0].replace(/\r/g, "");
if (!activePlan) {
  block(`${marker} is empty.`);
}

if (!path.isAbsolute(activePlan)) {
  activePlan = activePlan.startsWith(".plan/")
    ? path.join(repoRoot, activePlan)
    : path.join(planRoot, activePlan);
}

activePlan = normalizePath(activePlan);
if (path.dirname(activePlan) !== planRoot) {
  block(`Active developer plan must point inside .plan as a direct task folder: ${activePlan}`);
}

const taskFile = path.join(activePlan, "task.md");
if (!fs.existsSync(taskFile)) {
  block(`task.md was not found at ${taskFile}.`);
}

const questionsFile = path.join(activePlan, "questions.md");
if (!fs.existsSync(questionsFile)) {
  block(`questions.md was not found at ${questionsFile}.`);
}

if (fs.readFileSync(questionsFile, "utf8").trim() !== "NO_QUESTIONS") {
  block("questions.md must be exactly NO_QUESTIONS before using this tool.");
}

const plannerReadyFile = path.join(activePlan, ".planner-ready.json");
if (!fs.existsSync(plannerReadyFile)) {
  block(`.planner-ready.json was not found at ${plannerReadyFile}.`);
}
