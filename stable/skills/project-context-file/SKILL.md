---
name: project-context-file
description: Creates or updates AGENTS.md (open market standard) for the project, documenting business mission, technical toolchain, judgment boundaries, and operational instructions. Use when the user asks to create project context, document context for LLMs/agents, generate AGENTS.md, or onboard AI assistants.
license: MIT
metadata:
  tags: "agents-md, context, onboarding, documentation"
  category: "tooling"
---

# Project Context File (AGENTS.md)

Creates or updates an `AGENTS.md` file at the project root — the vendor-neutral standard adopted across modern AI coding tools (Cursor, Claude Code, Codex, Windsurf, Antigravity). Acts as a "README for agents", providing mission context, execution commands, and judgment boundaries without context bloating.

## When to Apply

Apply this skill whenever:
- The user asks to create project context, onboard AI assistants, or generate `AGENTS.md` / `CLAUDE.md`.
- A new repository is initiated or major architectural changes occur.
- An AI assistant exhibits recurring misunderstandings about project boundaries or testing procedures.

## Core Principles

### 1. Toolchain First Principle
Do **NOT** restate rules that linters, formatters, typecheckers, or compilers already enforce.
- *Bad*: Listing 20 Biome or ESLint formatting rules in prose.
- *Good*: Pointing to the configuration authority:
  ```markdown
  | Lint | `pnpm lint` | See biome.json |
  ```

### 2. Under 150 Lines
Keep `AGENTS.md` minimal, dense, and precise (strictly under **150 lines**). Only include facts that an AI agent cannot deduce directly from code or configuration files.

### 3. Avoid Context Anchoring
Avoid writing negative instructions like "do not use library X" — mentioning the banned pattern primes the model to recall it. Instead, document the required pattern clearly under **ALWAYS**, or configure linter rules that prevent the banned pattern structurally.

## Generation Workflow

### Step 1: Discover Project Context
Inspect the workspace statically:
1. Read existing `README.md`, package manifests (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`), and build scripts.
2. Identify primary test commands and linter entry points.
3. Determine architectural topology (monorepo vs single service, main entry points).

### Step 2: Draft AGENTS.md
Apply the standard template from [references/agents-md-template.md](references/agents-md-template.md):
- **Project Mission**: 2 to 4 sentences defining core domain purpose and hard technical constraints (e.g., local-first, zero-trust, ACID guarantees).
- **Toolchain**: Table with Build, Test, Lint, and Type Check commands and their configuration authorities.
- **Judgment Boundaries**:
  - `NEVER`: Hard security/operational stops (e.g., never commit `.env`, never introduce dependencies without discussion).
  - `ASK`: Human-in-the-loop gates (e.g., before database migrations, before deleting existing endpoints).
  - `ALWAYS`: Proactive mandates (e.g., explain plan before multi-file edits, handle errors explicitly).
- **Context Map**: High-level map only for non-obvious folder structures (omit standard framework paths like `src/components`).

### Step 3: Present for Confirmation
Show the proposed `AGENTS.md` draft to the user and request confirmation before writing to disk.

### Step 4: Symlink for Platform Compatibility
After writing `AGENTS.md`, establish compatibility with tools that read `CLAUDE.md` (only if `CLAUDE.md` does not already exist as an independent regular file):
```bash
if [ -f CLAUDE.md ] && [ ! -L CLAUDE.md ]; then
  echo "CLAUDE.md already exists as a regular file; keeping existing file."
else
  ln -sf AGENTS.md CLAUDE.md
fi
```

