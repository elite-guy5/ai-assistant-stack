# Overview
This document walks you through configuring an optimized AI coding environment. The goal is to reduce token waste, improve model response quality, and keep costs in check across agentic coding sessions.

# Recommended Layered Configuration

Apply all three layers for maximum effect in a production coding environment:

~~~
Layer 1 — Shell Proxy (rtk)
  └── Filters CLI outputs before they enter the prompt history
      Intercepts Bash tool calls and compresses output before it enters the prompt

Layer 2 — Prompt Simplification (caveman-skill)
  └── Forces sessions into a minimal, verbose-free response mode.
      Reduces output bloat in long sessions.

Layer 3 — Persistent Memory (kuzu-memory)
  └── Injects project decisions, conventions, and context at session start
      Stores learnings asynchronously — compounds value over time

Layer 4 — Workspace Rules (CLAUDE.md)
  └── Manages instructions via path-scoped lazy loading
      Keep global CLAUDE.md under 200 lines
      Offload domain tasks to on-demand skills
~~~

**Key principle:** Configure hooks at the shell level rather than relying on natural language prompts to instruct the agent to "compress output." Prompt-level instructions consume tokens and achieve only 70–85% compliance. Shell hooks achieve 100% coverage with zero token overhead.


# Pre-Reqs
Assuming you have your AI tool installed, you will need Node.js and Python installed in order to execute the commands below. To install, open your terminal in your **Home Directory** /Users/yourname on Mac,  /home/yourname on Linux, C:\Users\YourName.

### Node.js aks npm

GitHub Link: [https://github.com/npm/cli](https://github.com/npm/cli)

**macOS / Linux**
~~~sh
#homebrew
brew install node
~~~

**Windows**
~~~sh
# Download and install Chocolatey:
powershell -c "irm https://community.chocolatey.org/install.ps1|iex"
# Download and install Node.js:
choco install nodejs
~~~

### Python

**macOS / Linux**
~~~sh
brew install python
~~~

**Windows**
- Open Command Prompt or PowerShell as an Administrator (Right-click -> Run as Administrator).
- Run the following command:

~~~
DOS
winget install -e --id Python.Python.3
Restart your terminal for the changes to take effect.
~~~

### pipx

**macOS / Linux**
~~~sh
brew install pipx
~~~

**Windows**
~~~powershell
python -m pip install --user pipx
~~~


# Layer 1: rtk (Rust Token Killer)
GitHub Link: [GitHub: rtk-ai/rtk](https://github.com/rtk-ai/rtk)

Intercepts CLI tool calls (e.g., `git diff`, `cargo test`, `docker ps`) and filters output before it enters the prompt. Achieves **60–92% token reduction** on common commands with under 10ms latency.

> **Important:** rtk only intercepts Bash tool calls. Native agent tools (`Read`, `Grep`, `Glob`) bypass the hook — use `cat`, `rg`, `find` via Bash if you need rtk filtering on those operations.

### Step 1: Install

**macOS / Linux:**
~~~sh
# curl
curl -sSL https://install.rtk.ai | sh

# Or via Homebrew
brew install rtk-ai/tap/rtk
~~~

**Windows (PowerShell):**
~~~powershell
winget install rtk-ai.rtk
~~~

> **Windows note:** Install [WSL 2](https://learn.microsoft.com/en-us/windows/wsl/install) before proceeding. The Bash hook that intercepts shell commands requires a Unix shell. Without WSL, the hook is unavailable and rtk falls back to injecting instructions into `CLAUDE.md`, which increases prompt tokens rather than reducing them.

### Step 2: Initialize (Global Hook)

**macOS / Linux / WSL:**
~~~sh
rtk init --global
~~~

**Windows (limited mode, no hook):**
~~~sh
rtk init --global
# Note: runs in prompt-injection fallback mode without WSL
~~~

This injects a pre-tool Bash hook so commands like `git status` are automatically rewritten to `rtk git status` without any further configuration. On Windows without WSL, the hook is unavailable — use WSL for full functionality.

Just incase you use multiple AI tools and the global init configuration doesn't work, you can run one of these
~~~sh
# 1. Install for your AI tool
rtk init -g                     # Claude Code / Copilot (default)
rtk init -g --gemini            # Gemini CLI
rtk init -g --codex             # Codex (OpenAI)
rtk init -g --agent cursor      # Cursor
rtk init --agent windsurf       # Windsurf
rtk init --agent cline          # Cline / Roo Code
rtk init --agent kilocode       # Kilo Code
rtk init --agent antigravity    # Google Antigravity
rtk init --agent hermes         # Hermes

# 2. Restart your AI tool, then test
git status  # Automatically rewritten to rtk git status
~~~

### Step 3: VS Code Extension

Open the **Extensions** tab in VS Code (`Ctrl+Shift+X` / `Cmd+Shift+X`), search **rtk inspector**, and install the extension by **PeterMEFrandsen**.




# Layer 2: Caveman Skill (Claude Code)
GitHub Link: [GitHub: juliusbrussee/caveman](https://github.com/juliusbrussee/caveman)

Adds a `/caveman` slash command that forces Claude Code into a minimal, verbose-free response mode. Reduces output bloat in long sessions.

### Step 1: Global Install

**macOS / Linux / WSL:**
~~~sh
curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash
~~~

**Windows (PowerShell):**
~~~sh
irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex
~~~

If the global install doesn't work you can add it per AI tool 
~~~sh
npx skills add JuliusBrussee/caveman -a antigravity
npx skills add JuliusBrussee/caveman -a codex
claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman
gemini extensions install https://github.com/JuliusBrussee/caveman
~~~

# Layer 3: kuzu-memory
GitHub Link: [kuzu-memory](https://github.com/bobmatnyc/kuzu-memory)

Lightweight graph-backed memory system for AI coding tools. Stores project decisions, conventions, and context in a local KuzuDB graph database. Retrieves relevant memories in under 100ms to enhance prompts automatically. Integrates with Claude Code via MCP + hooks — memories are injected at session start without manual prompting.

### Step 1: Install

**macOS / Linux / WSL:**
~~~sh
pipx install kuzu-memory
~~~

### Step 2: Setup (global, run once)

- Claude Code

**macOS / Linux / WSL:**
~~~
kuzu-memory setup
~~~

Auto-detects Claude Code, installs MCP server and session hooks globally. No per-project config required.

- Claude Desktop and VS Code

**macOS / Linux / WSL:**
~~~sh
npm install -g @kuzu-memory/mcp-server
~~~

**Claude Desktop** — add to `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

**macOS / Linux / WSL:**
~~~json
{
  "mcpServers": {
    "kuzu-memory": {
      "command": "kuzu-memory",
      "args": ["mcp"]
    }
  }
}
~~~

**VS Code** — add to `~/.vscode/mcp.json`:

~~~json
{
  "mcpServers": {
    "kuzu-memory": {
      "command": "kuzu-memory",
      "args": ["mcp"],
      "env": {
        "KUZU_MEMORY_PROJECT_ROOT": "/path/to/your/project",
        "KUZU_MEMORY_DB": "/path/to/your/project/.kuzu-memory/memories.db"
      }
    }
  }
}
~~~





# Layer# 4: CLAUDE.md Configuration
A well-structured `CLAUDE.md` is the foundation. Keep it **under 200 lines**. It loads at every session start, so bloat here costs tokens on every turn.

### Global Preferences (`~/.claude/CLAUDE.md`)
Applies across all repositories on the machine. Use this for personal behavior rules and developer-specific defaults.

**Starter template — copy and adapt:**
~~~
# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.
Read existing files before writing. Don't re-read unless changed.
Thorough in reasoning, concise in output.
Skip files over 100KB unless required.
No sycophantic openers or closing fluff.
No emojis or em-dashes.
Do not guess APIs, versions, flags, commit SHAs, or package names. Verify by reading code or docs before asserting.


## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## Tooling

### RTK (Rust Token Killer)
Prefix all shell commands with `rtk` — intercepts and filters output before it enters the prompt.
See full command reference: @RTK.md

### Caveman Skill
Use `/caveman` to reduce output verbosity in long sessions.

### kuzu-memory
At session start: `kuzu-memory enhance "<topic>"` to load relevant context.
After significant operations: `kuzu-memory learn "<decision or finding>"`.

~~~
