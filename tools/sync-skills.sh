#!/usr/bin/env bash
# Synchronizes stable skills into supported AI environments via safe symlinks.
# Supported clients: Claude Code, Cursor, OpenAI Codex, Google Antigravity.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SRC="${SKILLS_SRC_DIR:-${REPO_ROOT}/stable/skills}"

TARGETS=(
  "${HOME}/.claude/skills"
  "${HOME}/.cursor/skills"
  "${HOME}/.codex/skills"
  "${HOME}/.gemini/config/skills"
  "${HOME}/.gemini/antigravity/skills"
)

DO_CLEAN=0
DO_CHECK=0
DO_FORCE=0
FILTER_CLIENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)
      DO_CLEAN=1
      shift
      ;;
    --check)
      DO_CHECK=1
      shift
      ;;
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
      echo "Usage: $0 [--check] [--force] [--clean] [--client <claude|cursor|codex|antigravity>]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$SRC" ]]; then
  echo "Error: Skills source directory not found: $SRC" >&2
  exit 1
fi

echo "=== AI Skills Synchronization ==="
echo "Source: $SRC"

matched_any=0

for target in "${TARGETS[@]}"; do
  # Filter client if requested
  if [[ -n "$FILTER_CLIENT" ]]; then
    if [[ "$FILTER_CLIENT" == "antigravity" || "$FILTER_CLIENT" == "gemini" ]]; then
      if [[ "$target" != *".gemini"* ]]; then
        continue
      fi
    elif [[ "$target" != *"$FILTER_CLIENT"* ]]; then
      continue
    fi
  fi
  matched_any=1

  client_name="$(basename "$(dirname "$target")")"
  if [[ "$target" == *".gemini/config"* ]]; then
    client_name="antigravity-config"
  elif [[ "$target" == *".gemini/antigravity"* ]]; then
    client_name="antigravity-ide"
  fi

  echo
  echo "Target environment: $client_name ($target)"

  if [[ $DO_CHECK -eq 1 ]]; then
    if [[ ! -d "$target" ]]; then
      echo "  Directory does not exist (client likely not installed)."
      continue
    fi
    for skill_dir in "$SRC"/*/; do
      name="$(basename "$skill_dir")"
      link="${target}/${name}"
      expected_target="${skill_dir%/}"
      if [[ -L "$link" ]]; then
        cur_target="$(readlink "$link" 2>/dev/null || true)"
        if [[ "$cur_target" == "$expected_target" ]]; then
          echo "  [OK] $name -> $cur_target"
        else
          echo "  [MISMATCH] $name -> $cur_target (points elsewhere; expected $expected_target)"
        fi
      elif [[ -e "$link" ]]; then
        echo "  [WARN] $name exists but is a regular file/directory (not a symlink)"
      else
        echo "  [MISSING] $name is not linked"
      fi
    done
    continue
  fi

  if [[ $DO_CLEAN -eq 1 ]]; then
    if [[ -d "$target" ]]; then
      for skill_dir in "$SRC"/*/; do
        name="$(basename "$skill_dir")"
        link="${target}/${name}"
        expected_target="${skill_dir%/}"
        if [[ -L "$link" ]]; then
          cur_target="$(readlink "$link" 2>/dev/null || true)"
          if [[ "$cur_target" == "$expected_target" ]]; then
            rm "$link"
            echo "  Removed link: $name"
          else
            echo "  [SKIP] $name -> $cur_target (not managed by this repository)"
          fi
        fi
      done
    fi
    continue
  fi

  mkdir -p "$target"

  for skill_dir in "$SRC"/*/; do
    name="$(basename "$skill_dir")"
    link="${target}/${name}"
    expected_target="${skill_dir%/}"

    if [[ -e "$link" && ! -L "$link" ]]; then
      echo "  [SKIP] '$link' exists and is not a symlink. Will not overwrite."
      continue
    fi

    if [[ -L "$link" ]]; then
      cur_target="$(readlink "$link" 2>/dev/null || true)"
      if [[ "$cur_target" == "$expected_target" && $DO_FORCE -eq 0 ]]; then
        echo "  [UP-TO-DATE] $name"
        continue
      elif [[ "$cur_target" != "$expected_target" && $DO_FORCE -eq 0 ]]; then
        echo "  [SKIP] '$link' points to '$cur_target' (unmanaged target, use --force to overwrite)"
        continue
      fi
    fi

    ln -sfn "$expected_target" "$link"
    echo "  [LINKED] $name -> $link"
  done
done

if [[ $matched_any -eq 0 ]]; then
  echo "No target environments matched filter '$FILTER_CLIENT'." >&2
  exit 1
fi

echo
echo "Sync complete."
