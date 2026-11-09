# Installation and Synchronization Guide

This guide details how to install, synchronize, verify, and roll back skills, tools, and agents from this repository across supported AI environments.

*Consulte a versão em [Português (Brasil)](./instalacao.pt-BR.md).*

---

## 1. Supported Environments & Discovery Scopes

The artifacts follow the open [Agent Skills Specification](https://agentskills.io/specification). Different AI tools locate skills and agents in distinct directories depending on the operating system:

| Client / Environment | Scope | Linux & macOS Path | Windows Path (`$env:USERPROFILE`) | Symlink / Link Type | Session Reload Required? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Claude Code** | Global Skills | `~/.claude/skills/<skill-name>/` | `.claude\skills\<skill-name>\` | Symlink / Junction | **Yes** — Restart Claude Code terminal session |
| **Claude Code** | Global Agents | `~/.claude/agents/<agent-name>.md` | `.claude\agents\<agent-name>.md` | Generated copy | **Yes** — Agent registry is frozen at boot |
| **OpenAI Codex** | Global Skills | `~/.codex/skills/<skill-name>/` | `.codex\skills\<skill-name>\` | Symlink / Junction | No — Picked up on subsequent turn |
| **Google Antigravity** | Global Skills | `~/.gemini/config/skills/<skill-name>/` (App/CLI)<br>`~/.gemini/antigravity/skills/<skill-name>/` (IDE) | `.gemini\config\skills\<skill-name>\`<br>`.gemini\antigravity\skills\<skill-name>\` | Symlink / Junction | No — Hot-reloaded dynamically |
| **Cursor** | Global Skills | `~/.cursor/skills/<skill-name>/` | `.cursor\skills\<skill-name>\` | Symlink / Junction | No — Instant live evaluation |
| **Cursor** | Global Agents | `~/.cursor/agents/<agent-name>.md` | `.cursor\agents\<agent-name>.md` | Symlink / Copy | No — Instant live evaluation |

### Operating System Compatibility Matrix

- **Linux**: Fully native POSIX symlinks (`ln -sfn`). Supported via `./tools/sync-skills.sh` and `./tools/build-agents.sh`.
- **macOS (Darwin)**: Fully native POSIX symlinks (`ln -sfn`). Compatible out of the box in Terminal / Zsh / Bash via `./tools/sync-skills.sh` and `./tools/build-agents.sh`. Paths resolve under `/Users/<username>/`.
- **Windows (Native PowerShell)**: Fully supported via `.\tools\sync-skills.ps1` and `.\tools\build-agents.ps1`. When Windows Developer Mode is disabled or running without Administrator privileges, `sync-skills.ps1` automatically uses NTFS **Directory Junctions**, which do not require elevated privileges.
- **Windows (Git Bash / WSL)**: Supported via `./tools/sync-skills.sh` and `./tools/build-agents.sh` (Git Bash requires Developer Mode or Administrator rights for `ln -s`).

---

## 2. Prerequisites

- **Git** (version 2.20+)
- **For Linux & macOS (or Windows Git Bash / WSL)**:
  - **Bash** and **Perl** (standard POSIX tools for `sync-skills.sh` and `build-agents.sh`)
- **For Windows Native**:
  - **PowerShell 5.1+** or **PowerShell Core (pwsh)** (no extra dependencies required)
- **Optional Tools**:
  - **GitHub CLI (`gh`)** (recommended for `release-manager` pull request publishing)
  - **Node.js 18+** (only required if running the CI validation suite locally)

---

## 3. Installation Methods

### Method A: Canonical Local Checkout & Sync Tools (Documented & Tested)

This is the recommended approach for developers managing multiple AI environments on the same machine.

1. **Clone the repository**:
   ```bash
   git clone https://github.com/aleemerich/resources-generative-ai.git ~/.local/share/resources-generative-ai
   cd ~/.local/share/resources-generative-ai
   ```

2. **Run the synchronization tools**:

   **On Linux / macOS (or Windows Git Bash / WSL):**
   ```bash
   # Synchronize stable skills into all detected global environments
   ./tools/sync-skills.sh

   # Symlinks agents to Cursor and compiles frontmatter/tool allowlists for Claude Code
   ./tools/build-agents.sh
   ```

   **On Windows (PowerShell):**
   ```powershell
   # Synchronize stable skills using symlinks or unprivileged NTFS junctions
   .\tools\sync-skills.ps1

   # Synchronize agents for Cursor and Claude Code
   .\tools\build-agents.ps1
   ```

3. **Target a specific client**:
   ```bash
   # Linux / macOS / Git Bash
   ./tools/sync-skills.sh --client claude

   # Windows PowerShell
   .\tools\sync-skills.ps1 -Client claude
   ```

### Method B: LLM-Assisted Installation (Documented & Tested)

You can ask your AI coding assistant to configure skills directly. Copy and paste the prompt below into your assistant session:

```markdown
You are assisting me with installing skills from the public repository:
https://github.com/aleemerich/resources-generative-ai

Please perform the following steps:
1. Detect my current AI assistant environment (Claude Code, Cursor, Codex, or Antigravity) and operating system.
2. Clone this repository to `~/.local/share/resources-generative-ai` (or run `git pull` if it already exists).
   - If running in a shell-restricted environment, inspect the manifest at:
     https://raw.githubusercontent.com/aleemerich/resources-generative-ai/main/catalog.json
     and download the required files relative to `https://raw.githubusercontent.com/aleemerich/resources-generative-ai/main/`.
3. Link the stable skills and agents to my environment's discovery directory:
   - On Windows (PowerShell): run `.\tools\sync-skills.ps1` (and `.\tools\build-agents.ps1` for Cursor / Claude Code).
   - On Linux / macOS / Git Bash: run `./tools/sync-skills.sh` (and `./tools/build-agents.sh` for Cursor / Claude Code).
   - If shell-restricted, place the downloaded skills directly into my environment's discovery path.
4. Report the exact skills and agents installed, their versions from catalog.json, and whether a session restart is required.
```

### Method C: Vercel Skills CLI Integration (*Planned / Future Implementation*)

> [!NOTE]
> *Status: Planned / Future Implementation*. This workflow relies on upstream registry indexing in the `skills` CLI catalog.

```bash
# Planned command (not yet active until registry registration)
npx skills add aleemerich/resources-generative-ai --skill to-the-point
```

---

## 4. Verifying Installed Skills and Agents

After installing, verify that your client acknowledges the new capabilities:

1. **In Claude Code**:
   Restart your terminal, then type `/` in the prompt. You should see `/factual-writer`, `/to-the-point`, and `/taskforce` listed among available skills.
2. **In Cursor**:
   Open a chat panel and type `@skills` or trigger a slash command (e.g. `/to-the-point` or `/taskforce`).
3. **In OpenAI Codex**:
   Check available skills under `~/.codex/skills/` or ask the assistant to list active capabilities.
4. **In Google Antigravity**:
   Check available skills in the session metadata or invoke a skill directly.

---

## 5. Updates, Version Pinning & Rollback

### Checking for Updates
```bash
cd ~/.local/share/resources-generative-ai
git fetch origin
git log HEAD..origin/main --oneline
```

### Updating to the Latest Stable Version
```bash
cd ~/.local/share/resources-generative-ai
git pull origin main
./tools/sync-skills.sh
./tools/build-agents.sh
```

### Pinning a Specific Release Version
To prevent breaking changes in production pipelines, pin the repository to an immutable tag:
```bash
cd ~/.local/share/resources-generative-ai
git checkout v1.0.0
./tools/sync-skills.sh --force
./tools/build-agents.sh
```

### Rollback Procedure
If an updated skill disrupts your workflow:
```bash
cd ~/.local/share/resources-generative-ai
git checkout HEAD~1
./tools/sync-skills.sh --force
./tools/build-agents.sh
```
*Note: Restart Claude Code if rolling back under Claude.*

---

## 6. Uninstallation

### Option 1: Automated Safe Uninstallation (Recommended)
Removes only the links and junctions that point to this repository, preserving any personal or third-party skills:

```bash
# Linux / macOS / Git Bash:
./tools/sync-skills.sh --clean

# Windows PowerShell:
.\tools\sync-skills.ps1 -Clean
```

### Option 2: Manual Removal
To safely unlink a specific skill without deleting personal files, verify that the entry is a symbolic link before removing:

```bash
# Linux / macOS / Git Bash (remove only if it is a symbolic link):
[ -L ~/.claude/skills/factual-writer ] && rm ~/.claude/skills/factual-writer
[ -L ~/.cursor/skills/factual-writer ] && rm ~/.cursor/skills/factual-writer
[ -L ~/.codex/skills/factual-writer ] && rm ~/.codex/skills/factual-writer
[ -L ~/.gemini/config/skills/factual-writer ] && rm ~/.gemini/config/skills/factual-writer
```

```powershell
# Windows PowerShell (remove only if it is a ReparsePoint / symbolic link):
Get-Item "$HOME\.claude\skills\factual-writer" -ErrorAction SilentlyContinue | Where-Object { $_.LinkType } | ForEach-Object { $_.Delete() }
```

---

## 7. Troubleshooting

| Symptom | Cause | Solution |
| :--- | :--- | :--- |
| Skill does not appear in Claude Code | Claude Code freezes its skill registry at boot | Fully restart Claude Code (`exit` and reopen) |
| Subagents not visible in Claude Code | `build-agents.sh` was not executed or session was not restarted | Run `./tools/build-agents.sh` and restart Claude Code |
| Symlink broken / file not found | Local repository clone was moved | Re-run `./tools/sync-skills.sh` to refresh links |
| Windows symlink privilege error | Windows Developer Mode disabled | Use native PowerShell (`.\tools\sync-skills.ps1`), which automatically falls back to NTFS directory junctions without requiring Administrator privileges, or enable Developer Mode in Windows Settings |
| Model ignores skill rules | Prompt ambiguous or conflicting active modes | Explicitly invoke skill with slash command (e.g. `/factual-writer`) |

