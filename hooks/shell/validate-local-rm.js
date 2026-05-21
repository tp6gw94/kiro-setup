#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const BLOCK_PREFIX = "BLOCKED: developer rm is limited to the current working directory.";

function block(reason) {
  console.error(BLOCK_PREFIX);
  console.error(reason);
  process.exit(2);
}

function parsePayload(input) {
  try {
    return JSON.parse(input || "{}");
  } catch (_err) {
    return {};
  }
}

function tokenize(command) {
  const tokens = [];
  let token = "";
  let quote = null;

  for (let i = 0; i < command.length; i += 1) {
    const char = command[i];

    if (!quote && /[;&|<>()`$]/.test(char)) {
      block("Use simple literal rm targets only; dynamic shell syntax is not allowed.");
    }

    if (!quote && /[ \t\r\n]/.test(char)) {
      if (token) {
        tokens.push(token);
        token = "";
      }
      continue;
    }

    if ((char === "'" || char === '"') && (!quote || quote === char)) {
      quote = quote ? null : char;
      continue;
    }

    if (char === "\\" && quote !== "'") {
      i += 1;
      if (i >= command.length) block("rm command has an unfinished escape sequence.");
      token += command[i];
      continue;
    }

    token += char;
  }

  if (quote) block("rm command has an unterminated quoted string.");
  if (token) tokens.push(token);
  return tokens;
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
  const relative = path.relative(root, candidate);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function commandTargets(tokens) {
  let start = -1;
  if (tokens[0] === "rm") start = 1;
  if (tokens[0] === "rtk" && tokens[1] === "rm") start = 2;
  if (start === -1) return null;

  const targets = [];
  let optionsEnded = false;
  for (const token of tokens.slice(start)) {
    if (!optionsEnded && token === "--") {
      optionsEnded = true;
      continue;
    }
    if (!optionsEnded && token.startsWith("-")) continue;
    targets.push(token);
  }
  return targets;
}

const input = fs.readFileSync(0, "utf8");
const payload = parsePayload(input);
const command = payload.tool_input?.command || "";
if (!command) process.exit(0);

const tokens = tokenize(command);
const targets = commandTargets(tokens);
if (targets === null) process.exit(0);

if (targets.length === 0) {
  block("rm command is missing a target.");
}

const cwd = normalizePath(payload.cwd || process.cwd());

for (const target of targets) {
  if (/[?*[{]/.test(target)) {
    block(`Use simple literal rm targets only; dynamic shell syntax is not allowed: ${target}`);
  }
  if (path.isAbsolute(target)) {
    block(`rm absolute paths are not allowed: ${target}`);
  }

  const resolved = normalizePath(path.join(cwd, target));
  if (!isUnderOrEqual(resolved, cwd)) {
    block(`rm target resolves outside current directory: ${target}`);
  }
}
