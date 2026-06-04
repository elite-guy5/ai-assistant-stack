[CmdletBinding()]
param(
  [switch]$NonInteractive,
  [switch]$DryRun,
  [switch]$Overwrite,
  [string]$ProjectScope,
  [switch]$SkipRtk,
  [switch]$SkipCaveman,
  [string]$RtkAgents = "claude,codex",
  [string]$CavemanArgs = ""
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$HomeDir = if ($env:TOKEN_SAVER_HOME) { $env:TOKEN_SAVER_HOME } else { [Environment]::GetFolderPath("UserProfile") }
if (-not $ProjectScope) {
  $ProjectScope = Join-Path (Join-Path $HomeDir "Documents") "git"
}

function Write-Setup {
  param([string]$Message)
  Write-Host $Message
}

function Invoke-SetupCommand {
  param(
    [string]$FilePath,
    [string[]]$Arguments = @()
  )

  $display = @($FilePath) + $Arguments
  if ($DryRun) {
    Write-Setup "dry-run: $($display -join ' ')"
    return
  }

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "command failed: $($display -join ' ')"
  }
}

function Read-YesNo {
  param(
    [string]$Prompt,
    [bool]$Default
  )

  if ($NonInteractive) {
    return $Default
  }

  $label = if ($Default) { "yes" } else { "no" }
  $answer = Read-Host "$Prompt [$label]"
  if ([string]::IsNullOrWhiteSpace($answer)) {
    return $Default
  }
  return $answer -match "^(y|yes)$"
}

function Read-TextDefault {
  param(
    [string]$Prompt,
    [string]$Default
  )

  if ($NonInteractive) {
    return $Default
  }

  $answer = Read-Host "$Prompt [$Default]"
  if ([string]::IsNullOrWhiteSpace($answer)) {
    return $Default
  }
  return $answer
}

function Copy-ManagedFile {
  param(
    [string]$Source,
    [string]$Target
  )

  if ($DryRun) {
    if ((-not (Test-Path $Target)) -or $Overwrite) {
      Write-Setup "dry-run: would install $Target"
    } elseif ((Get-FileHash $Source).Hash -eq (Get-FileHash $Target).Hash) {
      Write-Setup "dry-run: already current $Target"
    } else {
      Write-Setup "dry-run: would leave $Target unchanged and write $Target.new"
    }
    return
  }

  $parent = Split-Path -Parent $Target
  New-Item -ItemType Directory -Force -Path $parent | Out-Null

  if ((-not (Test-Path $Target)) -or $Overwrite) {
    Copy-Item -Force $Source $Target
    Write-Setup "installed $Target"
    return
  }

  if ((Get-FileHash $Source).Hash -eq (Get-FileHash $Target).Hash) {
    Write-Setup "already current $Target"
    return
  }

  Copy-Item -Force $Source "$Target.new"
  Write-Setup "left existing $Target unchanged; wrote $Target.new"
}

function Copy-RenderedFile {
  param(
    [string]$Source,
    [string]$Target
  )

  $temp = New-TemporaryFile
  try {
    $content = Get-Content -Raw $Source
    $content = $content.Replace("{{HOME}}", $HomeDir).Replace("{{PROJECT_SCOPE}}", $ProjectScope)
    Set-Content -NoNewline -Encoding UTF8 -Path $temp -Value $content
    Copy-ManagedFile -Source $temp -Target $Target
  } finally {
    Remove-Item -Force $temp -ErrorAction SilentlyContinue
  }
}

function Ensure-ClaudeSessionHook {
  $settingsPath = Join-Path $HomeDir ".claude/settings.json"
  $scriptPath = Join-Path $HomeDir ".agents/scripts/seed-project-instructions.ps1"
  $command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
  $hook = [ordered]@{ type = "command"; command = $command; timeout = 5 }

  if ($DryRun) {
    Write-Setup "dry-run: would ensure Claude SessionStart hook in $settingsPath"
    return
  }

  $settingsDir = Split-Path -Parent $settingsPath
  New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null

  if (Test-Path $settingsPath) {
    $raw = Get-Content -Raw $settingsPath
    $data = if ([string]::IsNullOrWhiteSpace($raw)) {
      [pscustomobject]@{}
    } else {
      $raw | ConvertFrom-Json
    }
  } else {
    $data = [pscustomobject]@{}
  }

  if (-not $data.PSObject.Properties["hooks"]) {
    $data | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{})
  }
  if (-not $data.hooks.PSObject.Properties["SessionStart"]) {
    $data.hooks | Add-Member -MemberType NoteProperty -Name SessionStart -Value @()
  }

  $exists = $false
  foreach ($entry in @($data.hooks.SessionStart)) {
    foreach ($existing in @($entry.hooks)) {
      $existingCommand = [string]$existing.command
      if ($existingCommand -eq $command -or ($existingCommand.Contains("seed-project-instructions") -and $existingCommand.Contains(".agents"))) {
        $exists = $true
      }
    }
  }

  if ($exists) {
    Write-Setup "already has SessionStart hook in $settingsPath"
    return
  }

  $sessionStart = @($data.hooks.SessionStart)
  $sessionStart += [pscustomobject]@{ hooks = @([pscustomobject]$hook) }
  $data.hooks.SessionStart = $sessionStart
  $data | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $settingsPath
  Write-Setup "added SessionStart hook to $settingsPath"
}

function Install-RtkBinary {
  if (Get-Command rtk -ErrorAction SilentlyContinue) {
    Write-Setup "rtk already installed: $((Get-Command rtk).Source)"
    return
  }

  $binDir = Join-Path $HomeDir ".local/bin"
  $zipPath = Join-Path ([IO.Path]::GetTempPath()) "rtk-windows.zip"
  $extractDir = Join-Path ([IO.Path]::GetTempPath()) ("rtk-windows-" + [Guid]::NewGuid().ToString("N"))

  if ($DryRun) {
    Write-Setup "dry-run: would download the latest rtk-x86_64-pc-windows-msvc.zip release asset"
    Write-Setup "dry-run: would extract rtk.exe to $binDir"
    return
  }

  $release = Invoke-RestMethod "https://api.github.com/repos/rtk-ai/rtk/releases/latest"
  $asset = $release.assets | Where-Object { $_.name -eq "rtk-x86_64-pc-windows-msvc.zip" } | Select-Object -First 1
  if (-not $asset) {
    throw "could not find RTK Windows release asset"
  }

  New-Item -ItemType Directory -Force -Path $binDir | Out-Null
  Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $zipPath
  New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
  Expand-Archive -Force -Path $zipPath -DestinationPath $extractDir
  $rtkExe = Get-ChildItem -Recurse -File -Path $extractDir -Filter "rtk.exe" | Select-Object -First 1
  if (-not $rtkExe) {
    throw "rtk.exe was not found in downloaded archive"
  }
  Copy-Item -Force $rtkExe.FullName (Join-Path $binDir "rtk.exe")
  Remove-Item -Force $zipPath
  Remove-Item -Recurse -Force $extractDir

  $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not ($currentUserPath -split ";" | Where-Object { $_ -eq $binDir })) {
    $newPath = if ([string]::IsNullOrWhiteSpace($currentUserPath)) { $binDir } else { "$currentUserPath;$binDir" }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$env:Path;$binDir"
    Write-Setup "added $binDir to user PATH"
  }
}

function Get-RtkInitArgs {
  param([string]$Agent)

  switch ($Agent) {
    "claude" { return @("init", "-g") }
    "codex" { return @("init", "-g", "--codex") }
    "gemini" { return @("init", "-g", "--gemini") }
    "copilot" { return @("init", "-g", "--copilot") }
    default { return @("init", "--agent", $Agent) }
  }
}

function Initialize-RtkAgents {
  if ($SkipRtk) {
    return
  }

  Install-RtkBinary
  Write-Warning "On native Windows, RTK installs the binary and config. Full shell-hook behavior is best under WSL."

  if (-not (Get-Command rtk -ErrorAction SilentlyContinue) -and -not $DryRun) {
    Write-Warning "rtk is not on PATH after install; skipping rtk init"
    return
  }

  foreach ($agent in $RtkAgents.Split(",")) {
    $cleanAgent = $agent.Trim()
    if (-not $cleanAgent) {
      continue
    }
    Invoke-SetupCommand -FilePath "rtk" -Arguments (Get-RtkInitArgs -Agent $cleanAgent)
  }
}

function Install-CavemanTool {
  if ($SkipCaveman) {
    return
  }

  if (-not (Get-Command npx -ErrorAction SilentlyContinue) -and -not $DryRun) {
    Write-Warning "npx is required to install Caveman; skipping"
    return
  }

  $args = @("-y", "github:JuliusBrussee/caveman", "--")
  if ($CavemanArgs) {
    $args += $CavemanArgs.Split(" ", [StringSplitOptions]::RemoveEmptyEntries)
  }
  if ($NonInteractive -and ($args -notcontains "--non-interactive")) {
    $args += "--non-interactive"
  }
  if ($DryRun -and ($args -notcontains "--dry-run")) {
    $args += "--dry-run"
  }
  Invoke-SetupCommand -FilePath "npx" -Arguments $args
}

if (-not $NonInteractive) {
  $ProjectScope = Read-TextDefault -Prompt "Project scope for instruction seeding" -Default $ProjectScope
  if (-not $SkipRtk) {
    $SkipRtk = -not (Read-YesNo -Prompt "Install and initialize RTK?" -Default $true)
  }
  if (-not $SkipRtk) {
    $RtkAgents = Read-TextDefault -Prompt "RTK agents to initialize, comma-separated" -Default $RtkAgents
  }
  if (-not $SkipCaveman) {
    $SkipCaveman = -not (Read-YesNo -Prompt "Install Caveman?" -Default $true)
  }
  if (-not $SkipCaveman) {
    $CavemanArgs = Read-TextDefault -Prompt "Extra Caveman args (examples: --all, --minimal, --only claude, --no-hooks)" -Default $CavemanArgs
  }
}

Copy-ManagedFile -Source (Join-Path $Root "templates/CLAUDE.global.md") -Target (Join-Path $HomeDir ".claude/CLAUDE.md")
Copy-RenderedFile -Source (Join-Path $Root "templates/AGENTS.global.md") -Target (Join-Path $HomeDir ".codex/AGENTS.md")
Copy-ManagedFile -Source (Join-Path $Root "templates/CLAUDE.project-template.md") -Target (Join-Path $HomeDir ".claude/CLAUDE.project-template.md")
Copy-ManagedFile -Source (Join-Path $Root "templates/AGENTS.project-template.md") -Target (Join-Path $HomeDir ".codex/AGENTS.project-template.md")
Copy-ManagedFile -Source (Join-Path $Root "scripts/optimize-ai.ps1") -Target (Join-Path $HomeDir ".agents/scripts/optimize-ai.ps1")
Copy-RenderedFile -Source (Join-Path $Root "scripts/seed-project-instructions.ps1") -Target (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.ps1")
Copy-RenderedFile -Source (Join-Path $Root "scripts/seed-project-instructions.sh") -Target (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.sh")

Ensure-ClaudeSessionHook
Initialize-RtkAgents
Install-CavemanTool

Write-Setup "setup complete"
$global:LASTEXITCODE = 0
