[CmdletBinding()]
param(
  [switch]$NonInteractive,
  [switch]$DryRun,
  [switch]$Overwrite,
  [switch]$OverwriteGlobalInstructions,
  [switch]$OverwriteProjectTemplates,
  [switch]$Uninstall,
  [string]$UninstallComponents = "",
  [string]$ProjectScope,
  [switch]$SkipRtk,
  [switch]$SkipCaveman,
  [string]$RtkAgents = "claude,codex",
  [string]$RtkMode = "auto",
  [string]$CavemanArgs = "",
  [string]$CavemanMode = "ultra"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$HomeDir = if ($env:TOKEN_SAVER_HOME) { $env:TOKEN_SAVER_HOME } else { [Environment]::GetFolderPath("UserProfile") }
$CavemanModes = @("lite", "full", "ultra", "wenyan-lite", "wenyan-full", "wenyan-ultra")
if (-not $ProjectScope) {
  $ProjectScope = Join-Path $HomeDir "Documents"
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

  $label = if ($Default) { "y" } else { "n" }
  $answer = Read-Host "$Prompt (y/n) [$label]"
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

function Assert-CavemanMode {
  param([string]$Mode)

  if ($CavemanModes -notcontains $Mode) {
    throw "invalid Caveman mode: $Mode. Valid Caveman modes: $($CavemanModes -join ',')"
  }
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
      Write-Setup "dry-run: would skip existing managed file $Target"
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

  Write-Setup "skipped existing managed file $Target"
}

function Copy-GlobalInstructionFile {
  param(
    [string]$Source,
    [string]$Target
  )

  if ($DryRun) {
    if (-not (Test-Path $Target)) {
      Write-Setup "dry-run: would install $Target"
    } elseif ($OverwriteGlobalInstructions) {
      Write-Setup "dry-run: would overwrite $Target"
    } else {
      Write-Setup "dry-run: would skip existing global instruction file $Target"
    }
    return
  }

  $parent = Split-Path -Parent $Target
  New-Item -ItemType Directory -Force -Path $parent | Out-Null

  if (-not (Test-Path $Target)) {
    Copy-Item -Force $Source $Target
    Write-Setup "installed $Target"
    return
  }

  if ($OverwriteGlobalInstructions) {
    Copy-Item -Force $Source $Target
    Write-Setup "overwrote $Target"
    return
  }

  Write-Setup "skipped existing global instruction file $Target"
}

function Copy-ProjectTemplateFile {
  param(
    [string]$Source,
    [string]$Target
  )

  if ($DryRun) {
    if (-not (Test-Path $Target)) {
      Write-Setup "dry-run: would install $Target"
    } elseif ($OverwriteProjectTemplates -or $Overwrite) {
      Write-Setup "dry-run: would overwrite $Target"
    } else {
      Write-Setup "dry-run: would skip existing project instruction template file $Target"
    }
    return
  }

  $parent = Split-Path -Parent $Target
  New-Item -ItemType Directory -Force -Path $parent | Out-Null

  if (-not (Test-Path $Target)) {
    Copy-Item -Force $Source $Target
    Write-Setup "installed $Target"
    return
  }

  if ($OverwriteProjectTemplates -or $Overwrite) {
    Copy-Item -Force $Source $Target
    Write-Setup "overwrote $Target"
    return
  }

  Write-Setup "skipped existing project instruction template file $Target"
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

function Copy-RenderedGlobalInstructionFile {
  param(
    [string]$Source,
    [string]$Target
  )

  $temp = New-TemporaryFile
  try {
    $content = Get-Content -Raw $Source
    $content = $content.Replace("{{HOME}}", $HomeDir).Replace("{{PROJECT_SCOPE}}", $ProjectScope)
    Set-Content -NoNewline -Encoding UTF8 -Path $temp -Value $content
    Copy-GlobalInstructionFile -Source $temp -Target $Target
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
    "cursor" { return @("init", "-g", "--agent", "cursor") }
    default { return @("init", "--agent", $Agent) }
  }
}

function Test-AgentCommandOrPath {
  param(
    [string]$CommandName,
    [string[]]$Paths = @()
  )

  if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
    return $true
  }

  foreach ($path in $Paths) {
    if (Test-Path $path) {
      return $true
    }
  }

  return $false
}

function Add-RtkAgent {
  param([string]$Agent)

  $agents = @($script:RtkAgents.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  if ($agents -contains $Agent) {
    return
  }

  $script:RtkAgents = (@($agents) + $Agent) -join ","
}

function Detect-RtkAgents {
  if ($RtkMode -ne "auto") {
    return
  }

  Add-RtkAgent "claude"
  if (Test-AgentCommandOrPath -CommandName "claude" -Paths @(Join-Path $HomeDir ".claude")) { Add-RtkAgent "claude" }
  if (Test-AgentCommandOrPath -CommandName "codex" -Paths @(Join-Path $HomeDir ".codex")) { Add-RtkAgent "codex" }
  if (Test-AgentCommandOrPath -CommandName "gemini" -Paths @(Join-Path $HomeDir ".gemini")) { Add-RtkAgent "gemini" }
  if (Test-AgentCommandOrPath -CommandName "cursor" -Paths @(Join-Path $HomeDir ".cursor")) { Add-RtkAgent "cursor" }
  if (Test-AgentCommandOrPath -CommandName "gh" -Paths @((Join-Path $HomeDir ".vscode"), (Join-Path $HomeDir ".config/Code/User"))) { Add-RtkAgent "copilot" }
  if (Test-AgentCommandOrPath -CommandName "opencode" -Paths @(Join-Path $HomeDir ".config/opencode")) { Add-RtkAgent "opencode" }
  if (Test-AgentCommandOrPath -CommandName "openclaw" -Paths @(Join-Path $HomeDir ".openclaw")) { Add-RtkAgent "openclaw" }
  if (Test-AgentCommandOrPath -CommandName "pi" -Paths @(Join-Path $HomeDir ".pi")) { Add-RtkAgent "pi" }
  if (Test-AgentCommandOrPath -CommandName "hermes" -Paths @(Join-Path $HomeDir ".hermes")) { Add-RtkAgent "hermes" }
  if (Test-AgentCommandOrPath -CommandName "cline" -Paths @((Join-Path $HomeDir ".config/cline"), (Join-Path $HomeDir ".cline"))) { Add-RtkAgent "cline" }
  if (Test-AgentCommandOrPath -CommandName "windsurf" -Paths @(Join-Path $HomeDir ".windsurf")) { Add-RtkAgent "windsurf" }
  if (Test-AgentCommandOrPath -CommandName "kilocode" -Paths @(Join-Path $HomeDir ".kilocode")) { Add-RtkAgent "kilocode" }
  if (Test-AgentCommandOrPath -CommandName "antigravity" -Paths @(Join-Path $HomeDir ".agents/rules")) { Add-RtkAgent "antigravity" }
}

function Test-RtkAgentEnabled {
  param([string]$Agent)

  return @($RtkAgents.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -contains $Agent
}

function Test-FileContains {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$Label
  )

  if (-not (Test-Path $Path)) {
    Write-Warning "missing ${Label}: $Path"
    return $false
  }

  $content = Get-Content -Raw $Path
  if ($content -notmatch $Pattern) {
    Write-Warning "$Label does not contain required RTK rule: $Path"
    return $false
  }

  return $true
}

function Initialize-RtkAgents {
  if ($SkipRtk) {
    return
  }

  Install-RtkBinary
  Detect-RtkAgents
  if (([Environment]::OSVersion.Platform -eq "Win32NT") -and (-not $env:WSL_DISTRO_NAME)) {
    Write-Warning "On native Windows, RTK installs the binary and config. Transparent shell-hook rewrite requires WSL."
  }

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

function Verify-RtkSetup {
  if ($SkipRtk) {
    return
  }

  if ($DryRun) {
    Write-Setup "dry-run: would verify RTK binary and assistant instruction wiring"
    return
  }

  $failures = 0
  if (-not (Get-Command rtk -ErrorAction SilentlyContinue)) {
    Write-Warning "rtk is not available on PATH after install/init"
    $failures += 1
  } else {
    & rtk --version | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "rtk is installed but failed verification: rtk --version"
      $failures += 1
    }
  }

  if (Test-RtkAgentEnabled "codex") {
    if (-not (Test-FileContains -Path (Join-Path $HomeDir ".codex/AGENTS.md") -Pattern "RTK\.md" -Label "Codex AGENTS.md")) { $failures += 1 }
    if (-not (Test-FileContains -Path (Join-Path $HomeDir ".codex/RTK.md") -Pattern 'Always prefix shell commands with `rtk`' -Label "Codex RTK.md")) { $failures += 1 }
  }

  if (Test-RtkAgentEnabled "claude") {
    if (-not (Test-FileContains -Path (Join-Path $HomeDir ".claude/CLAUDE.md") -Pattern "RTK\.md" -Label "Claude CLAUDE.md")) { $failures += 1 }
    if (-not (Test-FileContains -Path (Join-Path $HomeDir ".claude/RTK.md") -Pattern "Always prefix shell commands|automatically rewritten|Hook-Based Usage" -Label "Claude RTK.md")) { $failures += 1 }
  }

  if ($failures -gt 0) {
    throw "RTK setup verification failed; rerun with -OverwriteGlobalInstructions or inspect existing global instruction files"
  }

  Write-Setup "verified RTK setup"
}

function Install-CavemanAgentFallbacks {
  if (Get-Command gemini -ErrorAction SilentlyContinue) {
    Invoke-SetupCommand -FilePath "gemini" -Arguments @("extensions", "install", "https://github.com/JuliusBrussee/caveman")
  }
  if (Test-AgentCommandOrPath -CommandName "codex" -Paths @(Join-Path $HomeDir ".codex")) {
    Invoke-SetupCommand -FilePath "npx" -Arguments @("skills", "add", "JuliusBrussee/caveman", "-a", "codex")
  }
  if (Test-AgentCommandOrPath -CommandName "cursor" -Paths @(Join-Path $HomeDir ".cursor")) {
    Invoke-SetupCommand -FilePath "npx" -Arguments @("skills", "add", "JuliusBrussee/caveman", "-a", "cursor")
  }
  if (Test-AgentCommandOrPath -CommandName "windsurf" -Paths @(Join-Path $HomeDir ".windsurf")) {
    Invoke-SetupCommand -FilePath "npx" -Arguments @("skills", "add", "JuliusBrussee/caveman", "-a", "windsurf")
  }
  if (Test-AgentCommandOrPath -CommandName "cline" -Paths @((Join-Path $HomeDir ".config/cline"), (Join-Path $HomeDir ".cline"))) {
    Invoke-SetupCommand -FilePath "npx" -Arguments @("skills", "add", "JuliusBrussee/caveman", "-a", "cline")
  }
  if (Test-AgentCommandOrPath -CommandName "antigravity" -Paths @(Join-Path $HomeDir ".agents/rules")) {
    Invoke-SetupCommand -FilePath "npx" -Arguments @("skills", "add", "JuliusBrussee/caveman", "-a", "antigravity")
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

  if ($DryRun) {
    Write-Setup "dry-run: would write caveman default mode $CavemanMode"
  } else {
    $configDir = Join-Path $HomeDir ".config/caveman"
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    [pscustomobject]@{ defaultMode = $CavemanMode } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $configDir "config.json")
  }

  $installerArgs = @("--all")
  if ($CavemanArgs) {
    $extraArgs = @($CavemanArgs.Split(" ", [StringSplitOptions]::RemoveEmptyEntries))
    if ($extraArgs -contains "--all") {
      $installerArgs = @()
    }
    $installerArgs += $extraArgs
  }
  if ($NonInteractive -and ($installerArgs -notcontains "--non-interactive")) {
    $installerArgs += "--non-interactive"
  }
  if ($DryRun -and ($installerArgs -notcontains "--dry-run")) {
    $installerArgs += "--dry-run"
  }
  $args = @("-y", "github:JuliusBrussee/caveman", "--") + $installerArgs
  Invoke-SetupCommand -FilePath "npx" -Arguments $args
  Install-CavemanAgentFallbacks
}

function Test-UninstallComponent {
  param([string]$Component)

  if ([string]::IsNullOrWhiteSpace($UninstallComponents) -or $UninstallComponents -in @("all", "all available", "all-available")) {
    return $true
  }

  return @($UninstallComponents.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -contains $Component
}

function Reset-FileBlank {
  param([string]$Path)

  if ($DryRun) {
    Write-Setup "dry-run: would blank $Path"
    return
  }

  $parent = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  Set-Content -NoNewline -Encoding UTF8 -Path $Path -Value ""
  Write-Setup "blanked $Path"
}

function Remove-ManagedPath {
  param([string]$Path)

  if ($DryRun) {
    Write-Setup "dry-run: would remove $Path"
    return
  }

  if (Test-Path $Path) {
    Remove-Item -Force $Path
    Write-Setup "removed $Path"
  } else {
    Write-Setup "already absent $Path"
  }
}

function Remove-ClaudeSeedHook {
  $settingsPath = Join-Path $HomeDir ".claude/settings.json"

  if ($DryRun) {
    Write-Setup "dry-run: would remove token-saver SessionStart hooks from $settingsPath"
    return
  }
  if (-not (Test-Path $settingsPath)) {
    return
  }

  $raw = Get-Content -Raw $settingsPath
  $data = if ([string]::IsNullOrWhiteSpace($raw)) { [pscustomobject]@{} } else { $raw | ConvertFrom-Json }
  if ($data.PSObject.Properties["hooks"] -and $data.hooks.PSObject.Properties["SessionStart"]) {
    $entries = @()
    foreach ($entry in @($data.hooks.SessionStart)) {
      $hooks = @($entry.hooks | Where-Object { ([string]$_.command) -notmatch "seed-project-instructions" })
      if ($hooks.Count -gt 0) {
        $entry.hooks = $hooks
        $entries += $entry
      }
    }
    $data.hooks.SessionStart = $entries
  }
  $data | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $settingsPath
  Write-Setup "removed token-saver SessionStart hooks from $settingsPath"
}

function Remove-CavemanClaudeSettings {
  $settingsPath = Join-Path $HomeDir ".claude/settings.json"

  if ($DryRun) {
    Write-Setup "dry-run: would remove Caveman entries from $settingsPath"
    return
  }
  if (-not (Test-Path $settingsPath)) {
    return
  }

  $raw = Get-Content -Raw $settingsPath
  $data = if ([string]::IsNullOrWhiteSpace($raw)) { [pscustomobject]@{} } else { $raw | ConvertFrom-Json }
  if ($data.PSObject.Properties["hooks"]) {
    foreach ($hookName in @($data.hooks.PSObject.Properties.Name)) {
      $entries = @()
      foreach ($entry in @($data.hooks.$hookName)) {
        $hooks = @($entry.hooks | Where-Object { ($_ | ConvertTo-Json -Depth 20) -notmatch "caveman" })
        if ($hooks.Count -gt 0) {
          $entry.hooks = $hooks
          $entries += $entry
        }
      }
      $data.hooks.$hookName = $entries
    }
  }
  if ($data.PSObject.Properties["statusLine"] -and (($data.statusLine | ConvertTo-Json -Depth 20) -match "caveman")) {
    $data.PSObject.Properties.Remove("statusLine")
  }
  foreach ($prop in @("mcpServers", "plugins", "enabledPlugins")) {
    if ($data.PSObject.Properties[$prop]) {
      foreach ($name in @($data.$prop.PSObject.Properties.Name)) {
        $value = $data.$prop.$name | ConvertTo-Json -Depth 20
        if ($name -match "caveman" -or $value -match "caveman") {
          $data.$prop.PSObject.Properties.Remove($name)
        }
      }
    }
  }
  $data | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $settingsPath
  Write-Setup "removed Caveman entries from $settingsPath"
}

function Remove-CavemanCodexConfig {
  $configPath = Join-Path $HomeDir ".codex/config.toml"

  if ($DryRun) {
    Write-Setup "dry-run: would remove known Caveman entries from $configPath"
    return
  }
  if (-not (Test-Path $configPath)) {
    return
  }

  $out = New-Object System.Collections.Generic.List[string]
  $skip = $false
  foreach ($line in Get-Content $configPath) {
    if ($line -eq "[mcp_servers.fs_shrunk]" -or $line -like "[hooks.state.*caveman*") {
      $skip = $true
      continue
    }
    if ($line.StartsWith("[") -and $skip) {
      $skip = $false
    }
    if ($skip) {
      continue
    }
    if ($line -match "caveman") {
      continue
    }
    $out.Add($line)
  }
  Set-Content -Encoding UTF8 -Path $configPath -Value $out
  Write-Setup "removed known Caveman entries from $configPath"
}

function Uninstall-RtkComponents {
  Detect-RtkAgents
  foreach ($agent in $RtkAgents.Split(",")) {
    $cleanAgent = $agent.Trim()
    if (-not $cleanAgent) {
      continue
    }
    if ((Get-Command rtk -ErrorAction SilentlyContinue) -or $DryRun) {
      $args = @("init", "--uninstall") + @((Get-RtkInitArgs -Agent $cleanAgent)[1..((Get-RtkInitArgs -Agent $cleanAgent).Count - 1)])
      Invoke-SetupCommand -FilePath "rtk" -Arguments $args
    }
  }
  Remove-ManagedPath -Path (Join-Path $HomeDir ".codex/RTK.md")
  Remove-ManagedPath -Path (Join-Path $HomeDir ".claude/RTK.md")
}

function Uninstall-CavemanComponents {
  if ((Get-Command npx -ErrorAction SilentlyContinue) -or $DryRun) {
    Invoke-SetupCommand -FilePath "npx" -Arguments @("-y", "github:JuliusBrussee/caveman", "--", "--uninstall", "--non-interactive")
    Invoke-SetupCommand -FilePath "npx" -Arguments @("skills", "remove", "JuliusBrussee/caveman", "--all")
  } else {
    Write-Warning "npx not found; skipping Caveman uninstall commands"
  }
  if ((Get-Command gemini -ErrorAction SilentlyContinue) -or $DryRun) {
    Invoke-SetupCommand -FilePath "gemini" -Arguments @("extensions", "uninstall", "caveman")
  }
  Remove-ManagedPath -Path (Join-Path $HomeDir ".config/caveman/config.json")
  Remove-CavemanClaudeSettings
  Remove-CavemanCodexConfig
}

function Invoke-Uninstall {
  if ([string]::IsNullOrWhiteSpace($script:UninstallComponents) -or $script:UninstallComponents -in @("all", "all available", "all-available")) {
    $script:UninstallComponents = "all available"
  }
  if (Test-UninstallComponent "global-instructions") {
    Reset-FileBlank -Path (Join-Path $HomeDir ".claude/CLAUDE.md")
    Reset-FileBlank -Path (Join-Path $HomeDir ".codex/AGENTS.md")
  }
  if (Test-UninstallComponent "project-templates") {
    Remove-ManagedPath -Path (Join-Path $HomeDir ".claude/CLAUDE.project-template.md")
    Remove-ManagedPath -Path (Join-Path $HomeDir ".codex/AGENTS.project-template.md")
  }
  if (Test-UninstallComponent "seeding") {
    Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.sh")
    Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.ps1")
    Remove-ClaudeSeedHook
  }
  if (Test-UninstallComponent "ignore-optimizer") {
    Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/scripts/optimize-ai.sh")
    Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/scripts/optimize-ai.ps1")
  }
  if (Test-UninstallComponent "rtk") {
    Uninstall-RtkComponents
  }
  if (Test-UninstallComponent "caveman") {
    Uninstall-CavemanComponents
  }
}

if ($Uninstall) {
  if (-not $NonInteractive) {
    $UninstallComponents = Read-TextDefault -Prompt "Components to uninstall, comma-separated or 'all available' (global-instructions, project-templates, seeding, ignore-optimizer, rtk, caveman, all available)" -Default $(if ($UninstallComponents) { $UninstallComponents } else { "all available" })
  }
  if ([string]::IsNullOrWhiteSpace($UninstallComponents)) {
    $UninstallComponents = "all available"
  }
  Invoke-Uninstall
  Write-Setup "uninstall complete"
  $global:LASTEXITCODE = 0
  exit 0
}

if (-not $NonInteractive) {
  $ProjectScope = Read-TextDefault -Prompt "Enter project directory for project seeding instructions" -Default $ProjectScope
  if (-not $OverwriteGlobalInstructions) {
    $OverwriteGlobalInstructions = Read-YesNo -Prompt "Overwrite existing global Claude/Codex instruction files?" -Default $false
  }
  if (-not $OverwriteProjectTemplates) {
    $OverwriteProjectTemplates = Read-YesNo -Prompt "Overwrite existing project instruction template files?" -Default $false
  }
  if (-not $SkipRtk) {
    $SkipRtk = -not (Read-YesNo -Prompt "Install and initialize RTK?" -Default $true)
  }
  if (-not $SkipRtk) {
    $RtkAgents = Read-TextDefault -Prompt "RTK agents to initialize, comma-separated or 'all available'" -Default $RtkAgents
    if ($RtkAgents -in @("all", "all available", "all-available")) {
      $RtkAgents = ""
      $RtkMode = "auto"
    }
    $RtkMode = Read-TextDefault -Prompt "RTK setup mode" -Default $RtkMode
  }
  if (-not $SkipCaveman) {
    $SkipCaveman = -not (Read-YesNo -Prompt "Install Caveman?" -Default $true)
  }
  if (-not $SkipCaveman) {
    $CavemanMode = Read-TextDefault -Prompt "Caveman mode to use ($($CavemanModes -join ','))" -Default $CavemanMode
    $CavemanArgs = Read-TextDefault -Prompt "Extra Caveman args (examples: --all, --minimal, --only claude, --no-hooks)" -Default $CavemanArgs
  }
}

if (-not $SkipCaveman) {
  Assert-CavemanMode -Mode $CavemanMode
}

if ($RtkAgents -in @("all", "all available", "all-available")) {
  $RtkAgents = ""
  $RtkMode = "auto"
}

Copy-GlobalInstructionFile -Source (Join-Path $Root "templates/CLAUDE.global.md") -Target (Join-Path $HomeDir ".claude/CLAUDE.md")
Copy-RenderedGlobalInstructionFile -Source (Join-Path $Root "templates/AGENTS.global.md") -Target (Join-Path $HomeDir ".codex/AGENTS.md")
Copy-ProjectTemplateFile -Source (Join-Path $Root "templates/CLAUDE.project-template.md") -Target (Join-Path $HomeDir ".claude/CLAUDE.project-template.md")
Copy-ProjectTemplateFile -Source (Join-Path $Root "templates/AGENTS.project-template.md") -Target (Join-Path $HomeDir ".codex/AGENTS.project-template.md")
Copy-ManagedFile -Source (Join-Path $Root "scripts/optimize-ai.ps1") -Target (Join-Path $HomeDir ".agents/scripts/optimize-ai.ps1")
Copy-RenderedFile -Source (Join-Path $Root "scripts/seed-project-instructions.ps1") -Target (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.ps1")
Copy-RenderedFile -Source (Join-Path $Root "scripts/seed-project-instructions.sh") -Target (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.sh")

Ensure-ClaudeSessionHook
Initialize-RtkAgents
Verify-RtkSetup
Install-CavemanTool

Write-Setup "setup complete"
$global:LASTEXITCODE = 0
