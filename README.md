# Generative AI Resources

A curated, vendor-neutral repository of production-ready AI agent capabilities: Agent Skills, multi-agent workflows, review lenses, and operational guidelines compliant with the open [Agent Skills Specification](https://agentskills.io/specification).

*Read this in [Português (Brasil)](./README.pt-BR.md).*

---

## Overview

This repository provides modular, standardized capabilities designed to enhance modern AI coding assistants (such as Claude Code, OpenAI Codex, Cursor, and Google Antigravity). Rather than bloating context windows with giant static system prompts, these resources leverage **progressive disclosure**: lightweight metadata is registered at startup, while in-depth execution instructions, schemas, and templates are dynamically loaded into context only when needed.

---

## Directory Structure & Lifecycle States

Artifacts are categorized into lifecycle stages across all AI resource types (`skills`, `agents`, `hooks`, `rules`):

```text
├── stable/              # Battle-tested, production-ready resources (Default distribution)
│   ├── skills/          # Universal Agent Skills (SKILL.md)
│   ├── agents/          # Autonomous subagent persona definitions (taskforce)
│   ├── hooks/           # Lifecycle and automation hooks
│   └── rules/           # System prompt context rules
├── experimental/        # Incubation tier for novel, evolving capabilities
│   ├── skills/
│   ├── agents/
│   ├── hooks/
│   └── rules/
├── deprecated/          # Phased-out capabilities retained for migration windows
│   ├── skills/
│   ├── agents/
│   ├── hooks/
│   └── rules/
├── tools/               # Multi-platform synchronization, compiler, and validation tools
└── docs/                # Bilingual installation, synchronization, and maintenance guides
```

- **`stable/`**: Distributed by default. Zero corporate dependencies, fully verified behavior, and strict regression coverage.
- **`experimental/`**: Sandbox tier for developing and testing new skills, agents, hooks, and rules before promotion.
- **`deprecated/`**: Artifacts entering obsolescence, preserved across deprecation cycles to avoid breaking downstream setups.
- **`tools/`**: Automation scripts to sync skills (`sync-skills.sh`), compile agents (`build-agents.sh`), and validate integrity (`validate-catalog.js`).

---

## Catalog of Stable Skills

| Skill | Category | Description | Primary Triggers |
| :--- | :--- | :--- | :--- |
| **[`factual-writer`](./stable/skills/factual-writer/)** | Writing / Quality | Enforces factual, concise prose. Zero adjectives, no em-dashes, no fluff, data precision, and "peel-the-onion" narrative. Supports dual mode: writing and automated review. | `/factual-writer`, technical reports, post-mortems, RFCs |
| **[`to-the-point`](./stable/skills/to-the-point/)** | Output / Productivity | Action-first output tailored for ADHD and high-speed execution. Starts with runnable code/actions, numbers multi-step tasks (capped at 5), and eliminates preambles. | `/to-the-point`, `/direto-ao-ponto`, ADHD mode |
| **[`communication-style`](./stable/skills/communication-style/)** | Writing / Voice (PT-BR) | Natural Brazilian Portuguese communication style: active voice, direct answers, and elimination of generic AI-filler phrases. | Chat responses, technical docs in PT-BR |
| **[`technical-explanation-style`](./stable/skills/technical-explanation-style/)** | Code / Architecture (PT-BR) | Seven core rules and two review passes (conceptual + mechanical) for explaining code walkthroughs to developers without repositories open. | Code review explanations, PR descriptions |
| **[`post-change-cleanup-review`](./stable/skills/post-change-cleanup-review/)** | Code Quality | Structured post-modification review checklist targeting dead code, duplicate blocks, naming ambiguities, and test drift. | Post-refactor checks, PR hygiene |
| **[`post-change-tests-review`](./stable/skills/post-change-tests-review/)** | Quality Assurance | Systematically assesses test relevance, duplicates, compatibility issues, and missing test scenarios following code edits. | Test suite maintenance, TDD loops |
| **[`project-context-file`](./stable/skills/project-context-file/)** | Tooling / Onboarding | Creates and maintains minimal `AGENTS.md` context files (<150 lines) adhering to the "Toolchain First" and "Judgment Boundaries" principles. | `AGENTS.md` generation, AI onboarding |
| **[`taskforce`](./stable/skills/taskforce/)** | Multi-Agent Orchestration | Orchestrates an autonomous software engineering team (analyst, architect, implementer, reviewer, release-manager) with TDD and independent reviews. | `/taskforce`, features, refactors, investigations |

---

## Quickstart & Installation

### Option 1: Automatic Multi-Platform Sync (Recommended)

1. Clone this repository to your local machine:
   ```bash
   git clone https://github.com/aleemerich/resources-generative-ai.git ~/.local/share/resources-generative-ai
   cd ~/.local/share/resources-generative-ai
   ```

2. Run the synchronization tool for your operating system:

   **Linux / macOS / Windows (Git Bash or WSL):**
   ```bash
   ./tools/sync-skills.sh
   ./tools/build-agents.sh
   ```

   **Windows (Native PowerShell):**
   ```powershell
   .\tools\sync-skills.ps1
   .\tools\build-agents.ps1
   ```

   *The tools automatically detect installed clients (Claude Code, Cursor, Codex, Antigravity) and create safe symlinks without overwriting existing local skills. On Windows, `sync-skills.ps1` automatically falls back to directory junctions if Developer Mode is disabled, requiring no Administrator privileges.*

### Option 2: LLM-Assisted Setup

Copy and paste this prompt to your AI coding assistant (Claude Code, Cursor, Codex, or Antigravity):

> "You are assisting me with installing skills and subagents from `https://github.com/aleemerich/resources-generative-ai`.
> 1. Detect my current AI assistant environment (Claude Code, Cursor, Codex, or Antigravity) and operating system.
> 2. Clone this repository to `~/.local/share/resources-generative-ai` (or run `git pull` if it already exists).
> 3. Run the synchronization tools for my platform:
>    - On Windows (PowerShell): run `.\tools\sync-skills.ps1` (and `.\tools\build-agents.ps1` for Cursor / Claude Code).
>    - On Linux / macOS / Git Bash: run `./tools/sync-skills.sh` (and `./tools/build-agents.sh` for Cursor / Claude Code).
>    - If in a restricted environment without shell access, read `catalog.json` and download each skill file from `https://raw.githubusercontent.com/aleemerich/resources-generative-ai/main/<entryFile>` into my environment's discovery directory.
> 4. Report which skills and agents were installed, their versions from `catalog.json`, and whether a session reload is needed."

For detailed manual instructions and platform-specific discovery paths, see the **[Installation Guide](./docs/installation.md)**.

---

## Versioning & Updates

This repository maintains an independent Semantic Version (`MAJOR.MINOR.PATCH`) for each artifact inside `catalog.json`.

- **Check for updates**:
  ```bash
  cd ~/.local/share/resources-generative-ai
  git pull origin main
  ./tools/sync-skills.sh --check
  ```
- **Pin a specific release**:
  ```bash
  git checkout v1.0.0
  ./tools/sync-skills.sh --force
  ```
- **Rollback**:
  ```bash
  git checkout HEAD~1
  ./tools/sync-skills.sh --force
  ```

---

## Contributing & Maintenance

We welcome contributions! Please review our **[Maintenance & Governance Guide](./docs/maintenance.md)** for:
- How to add new skills compliant with the Agent Skills specification.
- Automated validation via `node tools/validate-catalog.js`.
- Criteria for promoting skills and managing lifecycle states.

---

## License

Unless otherwise noted in an artifact's subdirectory, all original contents of this repository are licensed under the **[MIT License](./LICENSE)**. Individual third-party artifacts preserve their original licenses (e.g., `to-the-point` licensed under MIT by Ayoub Ghriss).
