#!/usr/bin/env bash
# Synchronizes and compiles task force subagents for supported AI environments:
# Cursor, Claude Code, OpenAI Codex, and Google Antigravity.
#
# Inspects client discovery paths. If a client environment exists, synchronizes
# all subagents; otherwise, reports as skipped and continues to the next client.
#
# Subagents inherit the active session model by default across all clients.
# Field mapping applied for Claude Code:
#   readonly: true                     ->  tools: Read, Grep, Glob
#
# Claude Code freezes its agent registry at boot. After compiling, restart Claude Code.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SRC="${AGENT_SRC_DIR:-${REPO_ROOT}/stable/agents}"

DO_FORCE=0
FILTER_CLIENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      DO_FORCE=1
      shift
      ;;
    --client)
      FILTER_CLIENT="$2"
      case "$FILTER_CLIENT" in
        claude|cursor|codex|antigravity|gemini)
          ;;
        *)
          echo "Error: Unknown client '$FILTER_CLIENT'. Supported clients: claude, cursor, codex, antigravity" >&2
          exit 1
          ;;
      esac
      shift 2
      ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--force] [--client <claude|cursor|codex|antigravity>]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$SRC" ]]; then
  echo "Error: Agents source directory not found: $SRC" >&2
  exit 1
fi

tmpfile=""
trap '[[ -n "$tmpfile" && -f "$tmpfile" ]] && rm -f "$tmpfile"' EXIT

shopt -s nullglob
agents=("$SRC"/*.md)

if [[ ${#agents[@]} -eq 0 ]]; then
  echo "Error: No agent definitions found in $SRC" >&2
  exit 1
fi

echo "=== AI Subagents Synchronization ==="
echo "Source: $SRC (${#agents[@]} subagents)"
echo

sync_canonical_links() {
  local target_dir="$1"
  local label="$2"
  local base_dir="$3"

  if [[ ! -d "$base_dir" && ! -d "$target_dir" && $DO_FORCE -eq 0 ]]; then
    echo "Target environment: $label ($target_dir)"
    echo "  [SKIPPED] Environment not found ($base_dir does not exist)"
    echo
    return 0
  fi

  echo "Target environment: $label ($target_dir)"
  mkdir -p "$target_dir"

  for src in "${agents[@]}"; do
    local name="$(basename "$src")"
    local link="${target_dir}/${name}"

    if [[ -L "$link" ]]; then
      local cur_target="$(readlink "$link" 2>/dev/null || true)"
      if [[ "$cur_target" == "$src" ]]; then
        echo "  [UP-TO-DATE] $name"
      elif [[ $DO_FORCE -eq 1 ]]; then
        rm -f "$link"
        ln -s "$src" "$link"
        echo "  [LINKED] $name -> $link"
      else
        echo "  [SKIP] $name (symlink points to $cur_target, use --force)"
      fi
    elif [[ -e "$link" ]]; then
      if [[ $DO_FORCE -eq 1 ]]; then
        rm -f "$link"
        ln -s "$src" "$link"
        echo "  [LINKED] $name -> $link"
      else
        echo "  [SKIP] $name (regular file exists, use --force)"
      fi
    else
      ln -s "$src" "$link"
      echo "  [LINKED] $name -> $link"
    fi
  done
  echo
}

sync_compiled_agents() {
  local target_dir="$1"
  local label="$2"
  local base_dir="$3"
  local skill_path_replace="$4"
  local is_claude="$5"

  if [[ ! -d "$base_dir" && ! -d "$target_dir" && $DO_FORCE -eq 0 ]]; then
    echo "Target environment: $label ($target_dir)"
    echo "  [SKIPPED] Environment not found ($base_dir does not exist)"
    echo
    return 0
  fi

  echo "Target environment: $label ($target_dir)"
  mkdir -p "$target_dir"

  for src in "${agents[@]}"; do
    local name="$(basename "$src")"
    local dest="${target_dir}/${name}"

    if [[ -L "$dest" ]]; then
      if [[ $DO_FORCE -eq 1 ]]; then
        rm -f "$dest"
      else
        echo "  [SKIP] $name (destination is a symlink, use --force)"
        continue
      fi
    elif [[ -e "$dest" && $DO_FORCE -eq 0 ]]; then
      if ! grep -q "Managed by resources-generative-ai" "$dest" 2>/dev/null; then
        echo "  [SKIP] $name (existing unmanaged agent, use --force)"
        continue
      fi
      rm -f "$dest"
    fi

    tmpfile="$(mktemp "${target_dir}/.tmp_agent_XXXXXX")"

    if [[ "$is_claude" == "1" ]]; then
      perl -pe '
        s{\r?\n$}{};
        if ($. == 1 && /^---$/) {
          $_ = "---\n# Managed by resources-generative-ai";
        }
        s{^readonly:\s*true\s*$}{tools: Read, Grep, Glob};
        s{\~/\.cursor/skills/}{'"$skill_path_replace"'}g;
        $_ .= "\n";
      ' "$src" > "$tmpfile"
    else
      perl -pe '
        s{\r?\n$}{};
        if ($. == 1 && /^---$/) {
          $_ = "---\n# Managed by resources-generative-ai";
        }
        s{\~/\.cursor/skills/}{'"$skill_path_replace"'}g;
        $_ .= "\n";
      ' "$src" > "$tmpfile"
    fi

    mv -f "$tmpfile" "$dest"
    tmpfile=""
    echo "  [COMPILED] $name -> $dest"
  done
  echo
}

# 1. Cursor (Canonical Symlinks)
if [[ -z "$FILTER_CLIENT" || "$FILTER_CLIENT" == "cursor" ]]; then
  CURSOR_TARGET="${CURSOR_AGENTS_DIR:-${HOME}/.cursor/agents}"
  sync_canonical_links "$CURSOR_TARGET" "Cursor" "${HOME}/.cursor"
fi

# 2. Claude Code (Compiled frontmatter & allowlist)
if [[ -z "$FILTER_CLIENT" || "$FILTER_CLIENT" == "claude" ]]; then
  CLAUDE_TARGET="${CLAUDE_AGENTS_DIR:-${HOME}/.claude/agents}"
  sync_compiled_agents "$CLAUDE_TARGET" "Claude Code" "${HOME}/.claude" "~/.claude/skills/" 1
fi

# 3. OpenAI Codex (Compiled with Codex skill paths)
if [[ -z "$FILTER_CLIENT" || "$FILTER_CLIENT" == "codex" ]]; then
  CODEX_TARGET="${CODEX_AGENTS_DIR:-${HOME}/.codex/agents}"
  sync_compiled_agents "$CODEX_TARGET" "OpenAI Codex" "${HOME}/.codex" "~/.codex/skills/" 0
fi

# 4. Google Antigravity (Config & IDE agents)
if [[ -z "$FILTER_CLIENT" || "$FILTER_CLIENT" == "antigravity" || "$FILTER_CLIENT" == "gemini" ]]; then
  GEMINI_BASE="${HOME}/.gemini"
  if [[ ! -d "$GEMINI_BASE" && $DO_FORCE -eq 0 ]]; then
    echo "Target environment: Google Antigravity ($GEMINI_BASE)"
    echo "  [SKIPPED] Environment not found ($GEMINI_BASE does not exist)"
    echo
  else
    if [[ -d "${GEMINI_BASE}/config" || $DO_FORCE -eq 1 ]]; then
      sync_compiled_agents "${GEMINI_BASE}/config/agents" "Google Antigravity (config)" "${GEMINI_BASE}/config" "~/.gemini/config/skills/" 0
    fi
    if [[ -d "${GEMINI_BASE}/antigravity" || $DO_FORCE -eq 1 ]]; then
      sync_compiled_agents "${GEMINI_BASE}/antigravity/agents" "Google Antigravity (ide)" "${GEMINI_BASE}/antigravity" "~/.gemini/antigravity/skills/" 0
    fi
  fi
fi

echo "Synchronization complete."
