"use strict";

// Harden Claude Code settings.json for lean-ctx routing enforcement.
//   - Repoint the Bash PreToolUse hook to the rewrite wrapper.
//   - Repoint the Read/Grep/Glob PreToolUse hook to the redirect-enforce script.
//   - Ensure the lean-ctx edit/search tools are allow-listed.
// Idempotent: re-running produces the same result. Preserves unrelated config.
//
// Usage: node harden-claude-settings.js <settingsPath> <wrapperScript> <enforceScript>

const fs = require("fs");

const settingsPath = process.argv[2];
const wrapperScript = process.argv[3];
const enforceScript = process.argv[4];

if (!settingsPath || !wrapperScript || !enforceScript) {
  console.error("usage: harden-claude-settings.js <settingsPath> <wrapperScript> <enforceScript>");
  process.exit(2);
}

const REDIRECT_MATCHER =
  "Read|read|ReadFile|read_file|View|view|Grep|grep|Search|search|" +
  "ListFiles|list_files|ListDirectory|list_directory|Glob|glob";
const BASH_MATCHER = "Bash|bash";

const REQUIRED_ALLOW = [
  "mcp__lean-ctx__ctx_compose",
  "mcp__lean-ctx__ctx_patch",
  "mcp__lean-ctx__ctx_shell",
  "mcp__lean-ctx__ctx_glob",
  "mcp__lean-ctx__ctx_callgraph",
  "mcp__lean-ctx__ctx_call",
  "mcp__lean-ctx__ctx_expand",
];

const wrapperCommand = `bash ${wrapperScript}`;
const enforceCommand = `bash ${enforceScript}`;

let config = {};
if (fs.existsSync(settingsPath)) {
  const raw = fs.readFileSync(settingsPath, "utf8").trim();
  config = raw ? JSON.parse(raw) : {};
}
if (!config || typeof config !== "object" || Array.isArray(config)) {
  throw new Error("Claude Code settings must be a JSON object");
}

if (!config.hooks || typeof config.hooks !== "object" || Array.isArray(config.hooks)) {
  config.hooks = {};
}
if (!Array.isArray(config.hooks.PreToolUse)) {
  config.hooks.PreToolUse = [];
}

const isRewrite = (command) =>
  typeof command === "string" &&
  (command.includes("lean-ctx hook rewrite") ||
    command.includes("lean-ctx-rewrite-wrapper.sh"));
const isRedirect = (command) =>
  typeof command === "string" &&
  (command.includes("lean-ctx hook redirect") ||
    command.includes("lean-ctx-redirect-enforce.sh"));

let bashFound = false;
let redirectFound = false;

for (const block of config.hooks.PreToolUse) {
  if (!block || !Array.isArray(block.hooks)) continue;
  for (const hook of block.hooks) {
    if (!hook || typeof hook !== "object") continue;
    if (isRewrite(hook.command)) {
      hook.command = wrapperCommand;
      bashFound = true;
    } else if (isRedirect(hook.command)) {
      hook.command = enforceCommand;
      redirectFound = true;
    }
  }
}

if (!bashFound) {
  config.hooks.PreToolUse.push({
    hooks: [{ command: wrapperCommand, type: "command" }],
    matcher: BASH_MATCHER,
  });
}
if (!redirectFound) {
  config.hooks.PreToolUse.push({
    hooks: [{ command: enforceCommand, type: "command" }],
    matcher: REDIRECT_MATCHER,
  });
}

if (!config.permissions || typeof config.permissions !== "object" || Array.isArray(config.permissions)) {
  config.permissions = {};
}
if (!Array.isArray(config.permissions.allow)) {
  config.permissions.allow = [];
}
for (const entry of REQUIRED_ALLOW) {
  if (!config.permissions.allow.includes(entry)) {
    config.permissions.allow.push(entry);
  }
}

fs.writeFileSync(settingsPath, `${JSON.stringify(config, null, 2)}\n`);
