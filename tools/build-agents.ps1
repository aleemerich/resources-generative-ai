<#
.SYNOPSIS
  Publishes and compiles task force subagents for supported AI environments:
  Cursor, Claude Code, OpenAI Codex, and Google Antigravity on Windows.
.DESCRIPTION
  Inspects client discovery paths. If a client environment exists, synchronizes
  all subagents; otherwise, reports as skipped and continues to the next client.
.PARAMETER Force
  Overwrite existing regular files or unmanaged agent files at destination.
.PARAMETER Client
  Filter target client: claude, cursor, codex, antigravity.
#>
[CmdletBinding()]
param(
  [switch]$Force,
  [string]$Client = ""
)

$ErrorActionPreference = "Stop"

if ($Client) {
  $validClients = @("claude", "cursor", "codex", "antigravity", "gemini")
  if ($validClients -notcontains $Client.ToLower()) {
    Write-Error "Unknown client '$Client'. Supported clients: claude, cursor, codex, antigravity"
    exit 1
  }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
$Src = Join-Path $RepoRoot "stable\agents"

$UserProfile = $env:USERPROFILE
if (-not $UserProfile) {
  $UserProfile = $env:HOME
}

if (-not (Test-Path $Src)) {
  Write-Error "Agents source directory not found: $Src"
  exit 1
}

$agentFiles = Get-ChildItem -Path $Src -Filter "*.md"

if ($agentFiles.Count -eq 0) {
  Write-Error "No agent definitions found in $Src"
  exit 1
}

Write-Host "=== AI Subagents Synchronization (Windows PowerShell) ==="
Write-Host "Source: $Src ($($agentFiles.Count) subagents)`n"

$hasErrors = $false
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Sync-CanonicalLinks {
  param(
    [string]$TargetDir,
    [string]$Label,
    [string]$BaseDir
  )

  if ((-not (Test-Path $BaseDir)) -and (-not (Test-Path $TargetDir)) -and (-not $Force)) {
    Write-Host "Target environment: $Label ($TargetDir)"
    Write-Host "  [SKIPPED] Environment not found ($BaseDir does not exist)`n"
    return
  }

  Write-Host "Target environment: $Label ($TargetDir)"
  New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

  foreach ($agent in $agentFiles) {
    $name = $agent.Name
    $targetPath = Join-Path $TargetDir $name

    if (Test-Path $targetPath) {
      $item = Get-Item $targetPath -Force
      $isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

      if (-not $isReparse) {
        if (-not $Force) {
          Write-Host "  [SKIP] $name (regular file exists, use -Force)"
        } else {
          Remove-Item $targetPath -Force
          try {
            New-Item -ItemType SymbolicLink -Path $targetPath -Target $agent.FullName | Out-Null
            Write-Host "  [LINKED] $name -> $targetPath"
          } catch {
            Copy-Item -Path $agent.FullName -Destination $targetPath -Force
            Write-Host "  [COPIED] $name -> $targetPath"
          }
        }
      } else {
        if ($item.Target -eq $agent.FullName) {
          Write-Host "  [UP-TO-DATE] $name"
        } elseif (-not $Force) {
          Write-Host "  [SKIP] $name (symlink points to $($item.Target), use -Force)"
        } else {
          $item.Delete()
          try {
            New-Item -ItemType SymbolicLink -Path $targetPath -Target $agent.FullName | Out-Null
            Write-Host "  [LINKED] $name -> $targetPath"
          } catch {
            Copy-Item -Path $agent.FullName -Destination $targetPath -Force
            Write-Host "  [COPIED] $name -> $targetPath"
          }
        }
      }
    } else {
      try {
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $agent.FullName | Out-Null
        Write-Host "  [LINKED] $name -> $targetPath"
      } catch {
        Copy-Item -Path $agent.FullName -Destination $targetPath -Force
        Write-Host "  [COPIED] $name -> $targetPath"
      }
    }
  }
  Write-Host ""
}

function Sync-CompiledAgents {
  param(
    [string]$TargetDir,
    [string]$Label,
    [string]$BaseDir,
    [string]$SkillPathReplace,
    [bool]$IsClaude = $false
  )

  if ((-not (Test-Path $BaseDir)) -and (-not (Test-Path $TargetDir)) -and (-not $Force)) {
    Write-Host "Target environment: $Label ($TargetDir)"
    Write-Host "  [SKIPPED] Environment not found ($BaseDir does not exist)`n"
    return
  }

  Write-Host "Target environment: $Label ($TargetDir)"
  New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null

  foreach ($agent in $agentFiles) {
    $name = $agent.Name
    $dest = Join-Path $TargetDir $name

    if (Test-Path $dest) {
      $item = Get-Item $dest -Force
      $isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

      if ($isReparse) {
        if (-not $Force) {
          Write-Host "  [SKIP] $name (destination is a symlink, use -Force)"
          continue
        }
        $item.Delete()
      } else {
        $existing = Get-Content -Path $dest -Raw
        if ((-not $Force) -and ($existing -notmatch "Managed by resources-generative-ai")) {
          Write-Host "  [SKIP] $name (existing unmanaged agent, use -Force)"
          continue
        }
        Remove-Item $dest -Force
      }
    }

    $content = Get-Content -Path $agent.FullName -Raw
    $content = $content.Replace("`r`n", "`n")

    if ($IsClaude) {
      $content = [regex]::Replace($content, "(?m)^model:\s*claude-opus-5\[effort=high\]\s*$", "model: opus`neffort: high")
      $content = [regex]::Replace($content, "(?m)^model:\s*gpt-5\.6-sol-max\s*$", "model: sonnet`neffort: high")
      $content = [regex]::Replace($content, "(?m)^readonly:\s*true\s*$", "tools: Read, Grep, Glob")
    }

    $content = $content.Replace("~/.cursor/skills/", $SkillPathReplace)

    if ($content.StartsWith("---`n")) {
      $finalContent = "---`n# Managed by resources-generative-ai`n" + $content.Substring(4)
    } else {
      $finalContent = "---`n# Managed by resources-generative-ai`n" + $content
    }

    $tempFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempFile, $finalContent, $utf8NoBom)
    Move-Item -Path $tempFile -Destination $dest -Force
    Write-Host "  [COMPILED] $name -> $dest"
  }
  Write-Host ""
}

# 1. Cursor (Canonical Symlinks)
if (-not $Client -or $Client -eq "cursor") {
  $cursorBase = Join-Path $UserProfile ".cursor"
  $cursorTarget = if ($env:CURSOR_AGENTS_DIR) { $env:CURSOR_AGENTS_DIR } else { Join-Path $cursorBase "agents" }
  Sync-CanonicalLinks -TargetDir $cursorTarget -Label "Cursor" -BaseDir $cursorBase
}

# 2. Claude Code (Compiled frontmatter & allowlist)
if (-not $Client -or $Client -eq "claude") {
  $claudeBase = Join-Path $UserProfile ".claude"
  $claudeTarget = if ($env:CLAUDE_AGENTS_DIR) { $env:CLAUDE_AGENTS_DIR } else { Join-Path $claudeBase "agents" }
  Sync-CompiledAgents -TargetDir $claudeTarget -Label "Claude Code" -BaseDir $claudeBase -SkillPathReplace "~/.claude/skills/" -IsClaude $true
}

# 3. OpenAI Codex (Compiled with Codex skill paths)
if (-not $Client -or $Client -eq "codex") {
  $codexBase = Join-Path $UserProfile ".codex"
  $codexTarget = if ($env:CODEX_AGENTS_DIR) { $env:CODEX_AGENTS_DIR } else { Join-Path $codexBase "agents" }
  Sync-CompiledAgents -TargetDir $codexTarget -Label "OpenAI Codex" -BaseDir $codexBase -SkillPathReplace "~/.codex/skills/" -IsClaude $false
}

# 4. Google Antigravity (Config & IDE agents)
if (-not $Client -or $Client -eq "antigravity" -or $Client -eq "gemini") {
  $geminiBase = Join-Path $UserProfile ".gemini"
  if ((-not (Test-Path $geminiBase)) -and (-not $Force)) {
    Write-Host "Target environment: Google Antigravity ($geminiBase)"
    Write-Host "  [SKIPPED] Environment not found ($geminiBase does not exist)`n"
  } else {
    $configBase = Join-Path $geminiBase "config"
    $ideBase = Join-Path $geminiBase "antigravity"

    if ((Test-Path $configBase) -or $Force) {
      $configTarget = Join-Path $configBase "agents"
      Sync-CompiledAgents -TargetDir $configTarget -Label "Google Antigravity (config)" -BaseDir $configBase -SkillPathReplace "~/.gemini/config/skills/" -IsClaude $false
    }
    if ((Test-Path $ideBase) -or $Force) {
      $ideTarget = Join-Path $ideBase "agents"
      Sync-CompiledAgents -TargetDir $ideTarget -Label "Google Antigravity (ide)" -BaseDir $ideBase -SkillPathReplace "~/.gemini/antigravity/skills/" -IsClaude $false
    }
  }
}

if ($hasErrors) {
  Write-Error "Agents synchronization encountered errors."
  exit 1
}

Write-Host "Synchronization complete."
