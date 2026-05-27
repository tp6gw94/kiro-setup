#!/usr/bin/env node
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import readline from "node:readline";

const [, , serverPath, workspace, outside] = process.argv;

if (!serverPath || !workspace || !outside) {
  console.error("usage: test-local-fs-mcp-client.mjs <server> <workspace> <outside>");
  process.exit(1);
}

const child = spawn(process.execPath, [serverPath], {
  cwd: workspace,
  stdio: ["pipe", "pipe", "pipe"],
});

let nextId = 1;
const pending = new Map();
let stderr = "";

child.stderr.on("data", (chunk) => {
  stderr += chunk.toString("utf8");
});

readline.createInterface({ input: child.stdout }).on("line", (line) => {
  const message = JSON.parse(line);
  const entry = pending.get(message.id);
  if (!entry) return;
  pending.delete(message.id);
  entry.resolve(message);
});

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function request(method, params = {}) {
  const id = nextId++;
  const response = new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    setTimeout(() => {
      if (pending.delete(id)) {
        reject(new Error(`timeout waiting for ${method}; stderr=${stderr}`));
      }
    }, 2000);
  });

  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
  return response;
}

async function callTool(name, args) {
  return request("tools/call", { name, arguments: args });
}

async function assertToolOk(name, args) {
  const response = await callTool(name, args);
  assert(!response.error, `${name} failed unexpectedly: ${JSON.stringify(response)}`);
  assert(response.result?.isError !== true, `${name} returned tool error: ${JSON.stringify(response)}`);
  return response.result;
}

async function assertToolError(name, args, pattern) {
  const response = await callTool(name, args);
  assert(!response.error, `${name} returned JSON-RPC error instead of tool error: ${JSON.stringify(response)}`);
  assert(response.result?.isError === true, `${name} should have failed: ${JSON.stringify(response)}`);
  const text = response.result.content?.map((item) => item.text).join("\n") || "";
  assert(pattern.test(text), `${name} error did not match ${pattern}: ${text}`);
}

try {
  const init = await request("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "local-fs-test", version: "0.0.0" },
  });
  assert(init.result?.serverInfo?.name === "local-fs", "initialize should return serverInfo.name");

  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized", params: {} })}\n`);

  const tools = await request("tools/list");
  const names = tools.result?.tools?.map((tool) => tool.name).sort();
  assert(JSON.stringify(names) === JSON.stringify(["mkdir", "rm"]), `unexpected tools: ${JSON.stringify(names)}`);

  await assertToolOk("rm", { paths: ["file.txt"] });
  assert(!fs.existsSync(path.join(workspace, "file.txt")), "rm should delete relative file inside cwd");

  const absoluteInside = path.join(workspace, "dir", "file.txt");
  await assertToolOk("rm", { paths: [absoluteInside] });
  assert(!fs.existsSync(absoluteInside), "rm should accept absolute path inside cwd");

  const nestedDir = path.join(workspace, "nested", "child");
  await assertToolOk("mkdir", { paths: [nestedDir] });
  assert(fs.statSync(nestedDir).isDirectory(), "mkdir should create absolute path inside cwd");

  await assertToolOk("mkdir", { paths: ["relative", "relative/deeper"] });
  assert(fs.statSync(path.join(workspace, "relative", "deeper")).isDirectory(), "mkdir should create relative dirs");

  await assertToolError("rm", { paths: [workspace] }, /refuses to delete cwd/i);
  await assertToolError("rm", { paths: [path.join(outside, "file.txt")] }, /outside current working directory/i);
  await assertToolError("rm", { paths: ["../outside/file.txt"] }, /outside current working directory/i);
  await assertToolError("rm", { paths: ["link-outside-file"] }, /outside current working directory/i);
  await assertToolError("mkdir", { paths: [path.join(outside, "new")] }, /outside current working directory/i);
  await assertToolError("mkdir", { paths: ["link-outside-dir/new"] }, /outside current working directory/i);
} finally {
  child.stdin.end();
  child.kill();
}
