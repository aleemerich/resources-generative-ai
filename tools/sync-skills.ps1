<#
.SYNOPSIS
  Synchronizes stable skills into supported AI environments via safe symlinks or junctions.
  Supported clients: Claude Code, Cursor, OpenAI Codex, Google Antigravity.
.DESCRIPTION
  Creates symbolic links (or junctions if unprivileged) pointing from each AI assistant's
  global discovery directory to the repository's stable skills.
.PARAMETER Check
  Audit existing links without creating or modifying anything.
.PARAMETER Clean
  Remove symbolic links or junctions previously created by this script.
.PARAMETER Force
  Recreate links even if they point to other targets or already exist.
.PARAMETER Client
  Filter target environment: 'claude', 'cursor', 'codex', or 'antigravity'.
#>
[CmdletBinding()]
param(
  [switch]$Check,
  [switch]$Clean,
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
$Src = Join-Path $RepoRoot "stable\skills"

$UserProfile = $env:USERPROFILE
if (-not $UserProfile) {
  $UserProfile = $env:HOME
}

$Targets = @(
  (Join-Path $UserProfile ".claude\skills"),
  (Join-Path $UserProfile ".cursor\skills"),
  (Join-Path $UserProfile ".codex\skills"),
  (Join-Path $UserProfile ".gemini\config\skills"),
  (Join-Path $UserProfile ".gemini\antigravity\skills")
)

if (-not (Test-Path $Src)) {
  Write-Error "Skills source directory not found: $Src"
  exit 1
}

$hasErrors = $false

Write-Host "=== AI Skills Synchronization (Windows PowerShell) ==="
Write-Host "Source: $Src`n"

$matchedAny = $false

foreach ($target in $Targets) {
  if ($Client) {
    if ($Client -eq "antigravity" -or $Client -eq "gemini") {
      if ($target -notmatch "\.gemini") { continue }
    } elseif ($target -notmatch [regex]::Escape($Client)) {
      continue
    }
  }
  $matchedAny = $true

  $clientName = Split-Path (Split-Path $target -Parent) -Leaf
  if ($target -match "\.gemini[\\/]config") {
    $clientName = "antigravity-config"
  } elseif ($target -match "\.gemini[\\/]antigravity") {
    $clientName = "antigravity-ide"
  }

  Write-Host "Target environment: $clientName ($target)"

  if ($Check) {
    if (-not (Test-Path $target)) {
      Write-Host "  Directory does not exist (client likely not installed)."
      continue
    }
    $skills = Get-ChildItem -Directory -Path $Src
    foreach ($s in $skills) {
      $linkPath = Join-Path $target $s.Name
      if (Test-Path $linkPath) {
        $item = Get-Item $linkPath -Force
        $isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        if ($isReparse) {
          $targetVal = $item.Target
          if ($targetVal -eq $s.FullName) {
            Write-Host "  [OK] $($s.Name) -> $targetVal"
          } else {
            Write-Host "  [MISMATCH] $($s.Name) -> $targetVal (points elsewhere; expected $($s.FullName))"
          }
        } else {
          Write-Host "  [WARN] $($s.Name) exists but is a regular folder (not a link)"
        }
      } else {
        Write-Host "  [MISSING] $($s.Name) is not linked"
      }
    }
    continue
  }

  if ($Clean) {
    if (Test-Path $target) {
      $skills = Get-ChildItem -Directory -Path $Src
      foreach ($s in $skills) {
        $linkPath = Join-Path $target $s.Name
        if (Test-Path $linkPath) {
          $item = Get-Item $linkPath -Force
          $isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
          if ($isReparse) {
            # Only remove if it actually points to our source directory
            if ($item.Target -eq $s.FullName) {
              # Delete reparse point without recursion into target
              $item.Delete()
              Write-Host "  Removed link: $($s.Name)"
            } else {
              Write-Host "  [SKIP] $($s.Name) -> $($item.Target) (not managed by this repository)"
            }
          }
        }
      }
    }
    continue
  }

  if (-not (Test-Path $target)) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
  }

  $skills = Get-ChildItem -Directory -Path $Src
  foreach ($s in $skills) {
    $linkPath = Join-Path $target $s.Name

    if (Test-Path $linkPath) {
      $item = Get-Item $linkPath -Force
      $isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

      if (-not $isReparse) {
        Write-Host "  [SKIP] '$linkPath' exists and is not a link. Will not overwrite."
        continue
      }

      if ($isReparse) {
        if ((-not $Force) -and ($item.Target -eq $s.FullName)) {
          Write-Host "  [UP-TO-DATE] $($s.Name)"
          continue
        } elseif ((-not $Force) -and ($item.Target -ne $s.FullName)) {
          Write-Host "  [SKIP] '$linkPath' points to '$($item.Target)' (use -Force to overwrite)"
          continue
        }
        # Safe deletion of reparse point only
        $item.Delete()
      }
    }

    try {
      New-Item -ItemType SymbolicLink -Path $linkPath -Target $s.FullName | Out-Null
      Write-Host "  [LINKED:Symlink] $($s.Name) -> $linkPath"
    } catch {
      try {
        New-Item -ItemType Junction -Path $linkPath -Target $s.FullName | Out-Null
        Write-Host "  [LINKED:Junction] $($s.Name) -> $linkPath"
      } catch {
        Write-Host "  [FAILED] Could not create link for $($s.Name): $($_.Exception.Message)"
        $hasErrors = $true
      }
    }
  }
  Write-Host ""
}

if (-not $matchedAny) {
  Write-Error "No target environments matched filter '$Client'."
  exit 1
}

if ($hasErrors) {
  Write-Error "Skill synchronization encountered errors."
  exit 1
}

Write-Host "Sync complete."
