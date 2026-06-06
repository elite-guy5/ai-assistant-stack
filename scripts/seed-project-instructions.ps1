[CmdletBinding()]
param(
  [string]$Cwd = (Get-Location).Path
)

$HomeDir = if ($env:TOKEN_SAVER_HOME) { $env:TOKEN_SAVER_HOME } else { [Environment]::GetFolderPath("UserProfile") }
$DefaultProjectScope = "{{PROJECT_SCOPE}}"
if ($DefaultProjectScope -like "{{*}}") {
  $DefaultProjectScope = Join-Path $HomeDir "Documents"
}

$Scope = if ($env:PROJECT_SCOPE) { $env:PROJECT_SCOPE } else { $DefaultProjectScope }
$ClaudeTemplate = if ($env:CLAUDE_TEMPLATE) { $env:CLAUDE_TEMPLATE } else { Join-Path $HomeDir ".claude/CLAUDE.project-template.md" }
$CodexTemplate = if ($env:CODEX_TEMPLATE) { $env:CODEX_TEMPLATE } else { Join-Path $HomeDir ".codex/AGENTS.project-template.md" }
$DryRun = if ($env:DRY_RUN) { $env:DRY_RUN } else { "0" }

$scopeInfo = Get-Item -LiteralPath $Scope -ErrorAction SilentlyContinue
if (-not $scopeInfo -or -not $scopeInfo.PSIsContainer) {
  exit 0
}
$scopeFull = $scopeInfo.FullName.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$cwdFull = [IO.Path]::GetFullPath($Cwd)

if (-not ($cwdFull.StartsWith($scopeFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
          $cwdFull.StartsWith($scopeFull + [IO.Path]::AltDirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
  exit 0
}

$relative = $cwdFull.Substring($scopeFull.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$child = ($relative -split "[\\/]", 2)[0]
if ([string]::IsNullOrWhiteSpace($child) -or $child.StartsWith(".")) {
  exit 0
}

$project = Join-Path $scopeFull $child
$projectInfo = Get-Item -LiteralPath $project -ErrorAction SilentlyContinue
if (-not $projectInfo -or -not $projectInfo.PSIsContainer -or ($projectInfo.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
  exit 0
}
$projectFull = $projectInfo.FullName
if (-not ($projectFull.StartsWith($scopeFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
          $projectFull.StartsWith($scopeFull + [IO.Path]::AltDirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
  exit 0
}
$project = $projectFull

function Test-SafeTarget {
  param([string]$Target)

  $targetItem = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
  if ($targetItem -and ($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    return $false
  }

  $parent = Split-Path -Parent $Target
  while ($parent -and ($parent -ne $project)) {
    $parentItem = Get-Item -LiteralPath $parent -Force -ErrorAction SilentlyContinue
    if ($parentItem -and ($parentItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      return $false
    }
    $next = Split-Path -Parent $parent
    if ($next -eq $parent) {
      break
    }
    $parent = $next
  }

  return $true
}

function Copy-IfMissing {
  param(
    [string]$Template,
    [string]$Target
  )

  if (-not (Test-Path -PathType Leaf $Template)) {
    return
  }
  if (-not (Test-SafeTarget -Target $Target)) {
    return
  }
  if (Test-Path $Target) {
    return
  }

  if ($DryRun -eq "1") {
    Write-Output "would create $Target from $Template"
    return
  }

  Copy-Item $Template $Target
}

Copy-IfMissing -Template $ClaudeTemplate -Target (Join-Path $project "CLAUDE.md")
Copy-IfMissing -Template $CodexTemplate -Target (Join-Path $project "AGENTS.md")

$optimizer = Join-Path $PSScriptRoot "optimize-ai.ps1"
if (Test-Path -PathType Leaf $optimizer) {
  & $optimizer -Project $project
}
