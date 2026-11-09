#!/usr/bin/env bash
# Publishes and compiles task force subagents for Cursor and Claude Code.
#
# The .md files in stable/agents/ are the canonical definitions, written in Cursor's
# frontmatter dialect. Cursor consumes them through symlinks. Claude Code requires
# different frontmatter fields and a tool allowlist for read-only agents, so its
# copies are compiled automatically.
#
# Claude Code freezes its agent registry at boot. After running this script,
# restart Claude Code to load newly compiled agents.
#
# Field mapping applied for Claude Code:
#   model: claude-opus-5[effort=high]  ->  model: opus   + effort: high
#   model: gpt-5.6-sol-max             ->  model: sonnet + effort: high
#   readonly: true                     ->  tools: Read, Grep, Glob
#
# Why the readonly mapping is an allowlist and not a denylist:
# Cursor's `readonly: true` enforces a sandbox property. Claude Code relies on tool lists.
# Simply disallowing write tools leaves Bash active, which could write files via sed or echo.
# The allowlist (Read, Grep, Glob) ensures read-only guarantees.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SRC="${AGENT_SRC_DIR:-${REPO_ROOT}/stable/agents}"
CURSOR_DIR="${CURSOR_AGENTS_DIR:-${HOME}/.cursor/agents}"
CLAUDE_DIR="${CLAUDE_AGENTS_DIR:-${HOME}/.claude/agents}"

DO_FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      DO_FORCE=1
      shift
      ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--force]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$SRC" ]]; then
  echo "Error: Agents source directory not found: $SRC" >&2
  exit 1
fi

mkdir -p "$CURSOR_DIR" "$CLAUDE_DIR"

tmpfile=""
trap '[[ -n "$tmpfile" && -f "$tmpfile" ]] && rm -f "$tmpfile"' EXIT

shopt -s nullglob
found=0

for src in "$SRC"/*.md; do
  found=1
  name="$(basename "$src")"

  # 1. Cursor: symlink canonical definition with safety checks
  link="${CURSOR_DIR}/${name}"
  if [[ -L "$link" ]]; then
    cur_target="$(readlink "$link" 2>/dev/null || true)"
    if [[ "$cur_target" == "$src" ]]; then
      echo "up-to-date (Cursor): $link"
    elif [[ $DO_FORCE -eq 1 ]]; then
      rm -f "$link"
      ln -s "$src" "$link"
      echo "linked (Cursor): $link"
    else
      echo "skip (symlink points to $cur_target, use --force): $link"
    fi
  elif [[ -e "$link" ]]; then
    if [[ $DO_FORCE -eq 1 ]]; then
      rm -f "$link"
      ln -s "$src" "$link"
      echo "linked (Cursor): $link"
    else
      echo "skip (regular file exists, use --force): $link"
    fi
  else
    ln -s "$src" "$link"
    echo "linked (Cursor): $link"
  fi

  # 2. Claude Code: compile frontmatter and tool allowlist safely
  dest="${CLAUDE_DIR}/${name}"
  if [[ -L "$dest" ]]; then
    # Destination is a symlink: never write through it!
    if [[ $DO_FORCE -eq 1 ]]; then
      rm -f "$dest"
    else
      echo "skip (Claude Code destination is a symlink, use --force): $dest"
      continue
    fi
  elif [[ -e "$dest" && $DO_FORCE -eq 0 ]]; then
    if ! grep -q "Managed by resources-generative-ai" "$dest" 2>/dev/null; then
      echo "skip (existing unmanaged Claude Code agent, use --force): $dest"
      continue
    fi
    rm -f "$dest"
  fi

  # Secure temporary file to prevent symlink following
  tmpfile="$(mktemp "${CLAUDE_DIR}/.tmp_agent_XXXXXX")"

  # Handle CRLF, map fields, and inject management marker on line 2 inside frontmatter
  perl -pe '
    s{\r?\n$}{};
    if ($. == 1 && /^---$/) {
      $_ = "---\n# Managed by resources-generative-ai";
    }
    s{^model:\s*claude-opus-5\[effort=high\]\s*$}{model: opus\neffort: high};
    s{^model:\s*gpt-5\.6-sol-max\s*$}{model: sonnet\neffort: high};
    s{^readonly:\s*true\s*$}{tools: Read, Grep, Glob};
    s{\~/\.cursor/skills/}{\~/\.claude/skills/}g;
    $_ .= "\n";
  ' "$src" > "$tmpfile"

  mv -f "$tmpfile" "$dest"
  tmpfile=""
  echo "compiled (Claude Code): $dest"
done

if [[ $found -eq 0 ]]; then
  echo "Error: No agent definitions found in $SRC" >&2
  exit 1
fi

echo
echo "Agents synchronized successfully."
echo "Note: Claude Code freezes its agent registry at boot — restart your Claude Code session to load changes."
