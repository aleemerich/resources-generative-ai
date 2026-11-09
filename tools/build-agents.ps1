<#
.SYNOPSIS
  Publishes and compiles task force subagents for Cursor and Claude Code on Windows.
.DESCRIPTION
  Copies/links canonical definitions in stable\agents into Cursor, and compiles
  frontmatter and tool allowlists for Claude Code.
.PARAMETER Force
  Overwrite existing regular files or unmanaged agent files at destination.
#>
[CmdletBinding()]
param(
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
$Src = Join-Path $RepoRoot "stable\agents"

$UserProfile = $env:USERPROFILE
if (-not $UserProfile) {
  $UserProfile = $env:HOME
}

$CursorDir = Join-Path $UserProfile ".cursor\agents"
$ClaudeDir = Join-Path $UserProfile ".claude\agents"

if (-not (Test-Path $Src)) {
  Write-Error "Agents source directory not found: $Src"
  exit 1
}

New-Item -ItemType Directory -Path $CursorDir -Force | Out-Null
New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null

$agentFiles = Get-ChildItem -Path $Src -Filter "*.md"

if ($agentFiles.Count -eq 0) {
  Write-Error "No agent definitions found in $Src"
  exit 1
}

$hasErrors = $false

foreach ($agent in $agentFiles) {
  $name = $agent.Name

  # 1. Cursor: symlink or copy with safety checks
  $cursorTarget = Join-Path $CursorDir $name
  $cursorExists = Test-Path $cursorTarget

  if ($cursorExists) {
    $item = Get-Item $cursorTarget -Force
    $isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

    if (-not $isReparse) {
      if (-not $Force) {
        Write-Host "skip (regular file exists, use -Force): $cursorTarget"
      } else {
        Remove-Item $cursorTarget -Force
        try {
          New-Item -ItemType SymbolicLink -Path $cursorTarget -Target $agent.FullName | Out-Null
          Write-Host "linked (Cursor): $cursorTarget"
        } catch {
          Copy-Item -Path $agent.FullName -Destination $cursorTarget -Force
          Write-Host "copied (Cursor): $cursorTarget"
        }
      }
    } else {
      if ($item.Target -eq $agent.FullName) {
        Write-Host "up-to-date (Cursor): $cursorTarget"
      } elseif (-not $Force) {
        Write-Host "skip (symlink points to $($item.Target), use -Force): $cursorTarget"
      } else {
        $item.Delete()
        try {
          New-Item -ItemType SymbolicLink -Path $cursorTarget -Target $agent.FullName | Out-Null
          Write-Host "linked (Cursor): $cursorTarget"
        } catch {
          Copy-Item -Path $agent.FullName -Destination $cursorTarget -Force
          Write-Host "copied (Cursor): $cursorTarget"
        }
      }
    }
  } else {
    try {
      New-Item -ItemType SymbolicLink -Path $cursorTarget -Target $agent.FullName | Out-Null
      Write-Host "linked (Cursor): $cursorTarget"
    } catch {
      Copy-Item -Path $agent.FullName -Destination $cursorTarget -Force
      Write-Host "copied (Cursor): $cursorTarget"
    }
  }

  # 2. Claude Code: compile frontmatter and tool allowlist safely
  $claudeTarget = Join-Path $ClaudeDir $name

  if (Test-Path $claudeTarget) {
    $claudeItem = Get-Item $claudeTarget -Force
    $isClaudeReparse = ($claudeItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

    if ($isClaudeReparse) {
      if (-not $Force) {
        Write-Host "skip (Claude Code destination is a symlink, use -Force): $claudeTarget"
        continue
      }
      # Unlink reparse point without following it
      $claudeItem.Delete()
    } else {
      $existing = Get-Content -Path $claudeTarget -Raw
      if ((-not $Force) -and ($existing -notmatch "Managed by resources-generative-ai")) {
        Write-Host "skip (existing unmanaged Claude Code agent, use -Force): $claudeTarget"
        continue
      }
      Remove-Item $claudeTarget -Force
    }
  }

  $content = Get-Content -Path $agent.FullName -Raw
  # Normalize CRLF to LF
  $content = $content.Replace("`r`n", "`n")

  # Replace model specifications and readonly flag (works with LF or CRLF)
  $content = [regex]::Replace($content, "(?m)^model:\s*claude-opus-5\[effort=high\]\s*$", "model: opus`neffort: high")
  $content = [regex]::Replace($content, "(?m)^model:\s*gpt-5\.6-sol-max\s*$", "model: sonnet`neffort: high")
  $content = [regex]::Replace($content, "(?m)^readonly:\s*true\s*$", "tools: Read, Grep, Glob")
  $content = $content.Replace("~/.cursor/skills/", "~/.claude/skills/")

  # Inject marker on line 2 inside frontmatter so line 1 remains strictly '---'
  if ($content.StartsWith("---`n")) {
    $finalContent = "---`n# Managed by resources-generative-ai`n" + $content.Substring(4)
  } else {
    $finalContent = "---`n# Managed by resources-generative-ai`n" + $content
  }

  # Write via temporary file using UTF-8 without BOM for strict Anthropic validator compatibility
  $tempFile = [System.IO.Path]::GetTempFileName()
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($tempFile, $finalContent, $utf8NoBom)
  Move-Item -Path $tempFile -Destination $claudeTarget -Force
  Write-Host "compiled (Claude Code): $claudeTarget"
}

if ($hasErrors) {
  Write-Error "Agents synchronization encountered errors."
  exit 1
}

Write-Host "`nAgents synchronized successfully."
Write-Host "Note: Claude Code freezes its agent registry at boot - restart your Claude Code session to load changes."
