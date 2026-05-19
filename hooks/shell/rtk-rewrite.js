#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const CACHE = path.join(os.homedir(), ".cache", "rtk-hook-version-ok");
const LOG = "/tmp/rtk-hook.log";

function log(message) {
  try {
    fs.appendFileSync(LOG, `${message}\n`);
  } catch (_err) {
    // Logging is best-effort; hook behavior should not depend on /tmp writes.
  }
}

function commandExists(command) {
  const result = spawnSync("sh", ["-c", `command -v ${command}`], { stdio: "ignore" });
  return result.status === 0;
}

function parseVersion(output) {
  const match = output.match(/[0-9]+\.[0-9]+\.[0-9]+/);
  return match ? match[0] : "";
}

function versionIsSupported(version) {
  const [major, minor] = version.split(".").map((part) => Number(part));
  return major > 0 || minor >= 23;
}

function ensureSupportedRtk() {
  if (!commandExists("rtk")) {
    console.error("rtk-rewrite: rtk not found, skipping");
    process.exit(0);
  }

  if (fs.existsSync(CACHE)) return;

  const result = spawnSync("rtk", ["--version"], { encoding: "utf8" });
  const version = parseVersion(`${result.stdout || ""}${result.stderr || ""}`);
  if (!version) process.exit(0);

  if (!versionIsSupported(version)) {
    console.error(`rtk-rewrite: rtk >= 0.23.0 required (found ${version})`);
    process.exit(0);
  }

  fs.mkdirSync(path.dirname(CACHE), { recursive: true });
  fs.writeFileSync(CACHE, `${version}\n`);
}

function parsePayload(input) {
  try {
    return JSON.parse(input || "{}");
  } catch (_err) {
    return {};
  }
}

ensureSupportedRtk();

log(`[rtk-hook] fired at ${new Date().toString()}`);
const input = fs.readFileSync(0, "utf8");
log(`[rtk-hook] INPUT: ${input.trimEnd()}`);

const payload = parsePayload(input);
const command = payload.tool_input?.command || "";
if (!command) process.exit(0);

const result = spawnSync("rtk", ["rewrite", command], { encoding: "utf8" });
const rewritten = (result.stdout || "").trimEnd();

if ((result.status === 0 || result.status === 3) && rewritten && rewritten !== command) {
  log(`[rtk-hook] rewritten: ${rewritten}`);
  console.error(`BLOCKED: rtk rewrote this command. Run this instead: ${rewritten}`);
  process.exit(2);
}

if (result.status === 0 || result.status === 3) {
  log("[rtk-hook] unchanged, allowing");
  process.exit(0);
}

log(`[rtk-hook] rtk failed (exit ${result.status}), allowing original`);
