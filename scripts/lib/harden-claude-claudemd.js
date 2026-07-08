"use strict";

// Harden the lean-ctx guidance block in ~/.claude/CLAUDE.md so routing reads as
// an imperative gate instead of a soft preference. Operates only inside the
// `<!-- lean-ctx -->` ... `<!-- /lean-ctx -->` markers when present. Idempotent:
// once hardened, the source phrases are gone so re-running is a no-op.
//
// Usage: node harden-claude-claudemd.js <claudeMdPath>

const fs = require("fs");

const claudeMdPath = process.argv[2];
if (!claudeMdPath) {
  console.error("usage: harden-claude-claudemd.js <claudeMdPath>");
  process.exit(2);
}
if (!fs.existsSync(claudeMdPath)) {
  // Nothing to harden yet (e.g. lean-ctx setup did not run). Not an error.
  process.exit(0);
}

const original = fs.readFileSync(claudeMdPath, "utf8");

const OPEN = "<!-- lean-ctx -->";
const CLOSE = "<!-- /lean-ctx -->";
const start = original.indexOf(OPEN);
const end = original.indexOf(CLOSE);

let head = "";
let region = original;
let tail = "";
if (start !== -1 && end !== -1 && end > start) {
  head = original.slice(0, start);
  region = original.slice(start, end + CLOSE.length);
  tail = original.slice(end + CLOSE.length);
}

const OPENER_FROM =
  "When the `ctx_*` MCP tools are listed in this session, prefer them over native equivalents:";
const OPENER_TO =
  "For any code exploration, search, or edit, use `ctx_*` tools. Do NOT use native Read/Grep/Bash on source files unless a `ctx_*` call has already failed:";

const FALLBACK_FROM =
  "If no `ctx_*` tools are listed in this session, use the native tools throughout.";
const FALLBACK_TO =
  "If `ctx_*` tools are not listed, load lean-ctx before exploring code; do not fall back to native reads.";

const EDIT_GATE_TO =
  "Edits: `ctx_read(mode=anchored)` → `ctx_patch`. Native Read → Edit remains a fallback only when a ctx path fails. Write, Delete, Glob — use normally.";

region = region.split(OPENER_FROM).join(OPENER_TO);
region = region.split(FALLBACK_FROM).join(FALLBACK_TO);
// Edit-gate paragraph spans two lines; match the whole sentence flexibly.
region = region.replace(
  /Native `Read`[\s\S]*?Write, Delete, Glob — use normally\./,
  EDIT_GATE_TO
);

const updated = head + region + tail;
if (updated !== original) {
  fs.writeFileSync(claudeMdPath, updated);
}
