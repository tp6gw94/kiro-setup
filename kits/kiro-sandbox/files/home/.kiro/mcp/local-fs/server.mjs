#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import readline from "node:readline";

const SERVER_INFO = { name: "local-fs", version: "0.1.0" };
const PROTOCOL_VERSION = "2024-11-05";

function normalizeExistingPrefix(value) {
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

function cwdRoot() {
  return normalizeExistingPrefix(process.cwd());
}

function resolveInsideCwd(rawPath) {
  if (typeof rawPath !== "string" || rawPath.trim() === "") {
    throw new Error("Path must be a non-empty string.");
  }

  const root = cwdRoot();
  const candidate = path.isAbsolute(rawPath)
    ? normalizeExistingPrefix(rawPath)
    : normalizeExistingPrefix(path.join(root, rawPath));

  if (!isUnderOrEqual(candidate, root)) {
    throw new Error(`Path resolves outside current working directory: ${rawPath}`);
  }

  return { root, candidate };
}

function ensurePaths(args) {
  const paths = args?.paths;
  if (!Array.isArray(paths) || paths.length === 0) {
    throw new Error("Expected arguments.paths to be a non-empty array.");
  }
  return paths;
}

function textResult(text, isError = false) {
  return {
    content: [{ type: "text", text }],
    isError,
  };
}

function toolError(error) {
  const message = error instanceof Error ? error.message : String(error);
  return textResult(message, true);
}

function rmTool(args) {
  const paths = ensurePaths(args);
  const recursive = args?.recursive !== false;
  const removed = [];

  for (const target of paths) {
    const { root, candidate } = resolveInsideCwd(target);
    if (candidate === root) {
      throw new Error("rm refuses to delete cwd.");
    }

    fs.rmSync(candidate, {
      recursive,
      force: Boolean(args?.force),
    });
    removed.push(path.relative(root, candidate) || ".");
  }

  return textResult(`Removed ${removed.join(", ")}`);
}

function mkdirTool(args) {
  const paths = ensurePaths(args);
  const created = [];

  for (const target of paths) {
    const { root, candidate } = resolveInsideCwd(target);
    fs.mkdirSync(candidate, { recursive: args?.recursive !== false });
    created.push(path.relative(root, candidate) || ".");
  }

  return textResult(`Created ${created.join(", ")}`);
}

const tools = [
  {
    name: "rm",
    description: "Delete files or directories that resolve inside the current working directory.",
    inputSchema: {
      type: "object",
      properties: {
        paths: {
          type: "array",
          items: { type: "string" },
          minItems: 1,
          description: "Relative or absolute paths. Absolute paths are allowed only inside cwd.",
        },
        recursive: {
          type: "boolean",
          default: true,
          description: "Delete directories recursively. Defaults to true.",
        },
        force: {
          type: "boolean",
          default: false,
          description: "Ignore missing paths. Defaults to false.",
        },
      },
      required: ["paths"],
      additionalProperties: false,
    },
  },
  {
    name: "mkdir",
    description: "Create directories that resolve inside the current working directory.",
    inputSchema: {
      type: "object",
      properties: {
        paths: {
          type: "array",
          items: { type: "string" },
          minItems: 1,
          description: "Relative or absolute directory paths. Absolute paths are allowed only inside cwd.",
        },
        recursive: {
          type: "boolean",
          default: true,
          description: "Create parent directories. Defaults to true.",
        },
      },
      required: ["paths"],
      additionalProperties: false,
    },
  },
];

function handleRequest(message) {
  switch (message.method) {
    case "initialize":
      return {
        protocolVersion: message.params?.protocolVersion || PROTOCOL_VERSION,
        capabilities: { tools: {} },
        serverInfo: SERVER_INFO,
      };
    case "tools/list":
      return { tools };
    case "tools/call": {
      const name = message.params?.name;
      const args = message.params?.arguments || {};
      try {
        if (name === "rm") return rmTool(args);
        if (name === "mkdir") return mkdirTool(args);
        return textResult(`Unknown tool: ${name}`, true);
      } catch (error) {
        return toolError(error);
      }
    }
    default:
      return null;
  }
}

function send(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

readline.createInterface({ input: process.stdin }).on("line", (line) => {
  if (!line.trim()) return;

  let message;
  try {
    message = JSON.parse(line);
  } catch (error) {
    send({
      jsonrpc: "2.0",
      id: null,
      error: { code: -32700, message: "Parse error" },
    });
    return;
  }

  if (!Object.hasOwn(message, "id")) return;

  try {
    const result = handleRequest(message);
    if (result === null) {
      send({
        jsonrpc: "2.0",
        id: message.id,
        error: { code: -32601, message: `Method not found: ${message.method}` },
      });
      return;
    }

    send({ jsonrpc: "2.0", id: message.id, result });
  } catch (error) {
    send({
      jsonrpc: "2.0",
      id: message.id,
      error: {
        code: -32603,
        message: error instanceof Error ? error.message : String(error),
      },
    });
  }
});
