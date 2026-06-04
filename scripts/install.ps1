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
  [string]$AiApps = "claude,codex",
  [string]$Assets = "all",
  [string]$RtkAgents = "claude,codex",
  [string]$RtkMode = "auto",
  [string]$CavemanArgs = "",
  [string]$CavemanMode = "ultra"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$HomeDir = if ($env:TOKEN_SAVER_HOME) { $env:TOKEN_SAVER_HOME } else { [Environment]::GetFolderPath("UserProfile") }
$ManifestPath = if ($env:TOKEN_SAVER_MANIFEST) { $env:TOKEN_SAVER_MANIFEST } else { Join-Path $HomeDir ".agents/install_manifest.json" }
$CavemanModes = @("lite", "full", "ultra", "wenyan-lite", "wenyan-full", "wenyan-ultra")
$UninstallActive = $false
$UninstallReport = @()
$InstallActive = $false
$InstallReport = @()
$CurrentTool = ""
if (-not $ProjectScope) {
  $ProjectScope = Join-Path $HomeDir "Documents"
}

function Write-Setup {
  param([string]$Message)
  Write-Host $Message
}

function Get-ProgressBar {
  param(
    [int]$Current,
    [int]$Total,
    [int]$Width = 30
  )
  $filled = [math]::Floor(($Current * $Width) / $Total)
  if ($filled -lt 0) { $filled = 0 }
  if ($filled -gt $Width) { $filled = $Width }
  $empty = $Width - $filled
  return ('#' * $filled) + ('-' * $empty)
}

function Write-StepProgress {
  param(
    [string]$Phase,
    [int]$Current,
    [int]$Total,
    [string]$Message
  )
  $bar = Get-ProgressBar -Current $Current -Total $Total
  Write-Host "$Phase [$bar] $Current/$Total $Message"
}

function Add-UninstallReport {
  param(
    [string]$Section,
    [string]$Tool,
    [string]$Category,
    [string]$Item,
    [string]$Status = "ok"
  )

  $script:UninstallReport += [pscustomobject]@{
    Section = $Section
    Tool = $Tool
    Category = $Category
    Item = $Item
    Status = $Status
  }
}

function Add-InstallReport {
  param(
    [string]$Section,
    [string]$Tool,
    [string]$Category,
    [string]$Item,
    [string]$Status = "ok"
  )

  if (-not $script:InstallActive) {
    return
  }

  $script:InstallReport += [pscustomobject]@{
    Section = $Section
    Tool = $Tool
    Category = $Category
    Item = $Item
    Status = $Status
  }
}

function Get-ToolName {
  param([string]$Component)
  switch ($Component) {
    "caveman" { return "Caveman" }
    "rtk" { return "RTK" }
    "ignore-optimizer" { return "Optimize-AI" }
    "seeding" { return "Seed Project" }
    "project-instructions" { return "Project Instructions" }
    "reset-global-instructions" { return "Instruction Files" }
    default { return $Component }
  }
}

function Add-InstallFileReport {
  param(
    [string]$Component,
    [string]$Category,
    [string]$Item
  )

  switch ($Component) {
    "global-instructions" { Add-InstallReport -Section "Instruction Files" -Tool "" -Category $Category -Item $Item }
    "project-templates" { Add-InstallReport -Section "Templates" -Tool "" -Category $Category -Item $Item }
    default { Add-InstallReport -Section "Skills and Plugins" -Tool (Get-ToolName $Component) -Category $Category -Item $Item }
  }
}

function Show-InstallReport {
  if ($script:InstallReport.Count -eq 0) {
    return
  }

  function Rule([string]$Char = "-") { Write-Host ($Char * 50) }
  function Section([string]$Name, [string]$Char = "-") { Write-Host $Name; Rule $Char }
  function Mark([string]$Status) { if ($Status -eq "warn") { return "!" }; return "✓" }
  function UniqueItems($Rows) { @($Rows | ForEach-Object { $_.Item } | Where-Object { $_ } | Select-Object -Unique) }
  function PrintRows($Rows) { foreach ($row in $Rows) { Write-Host "$(Mark $row.Status) $($row.Item)" } }
  function PrintCategoryRows($Rows) {
    foreach ($category in @($Rows | ForEach-Object { $_.Category } | Where-Object { $_ } | Select-Object -Unique)) {
      $entries = @($Rows | Where-Object Category -eq $category)
      $items = UniqueItems $entries
      Write-Host "$category ($($items.Count))"
      PrintRows $entries
    }
  }

  $instruction = @($script:InstallReport | Where-Object Section -eq "Instruction Files")
  if ($instruction.Count) { Section "Instruction Files"; PrintCategoryRows $instruction; Write-Host "" }

  $toolRows = @($script:InstallReport | Where-Object Section -eq "Skills and Plugins")
  if ($toolRows.Count) {
    Section "Skills and Plugins" "="
    foreach ($tool in @("Caveman", "RTK", "Optimize-AI", "Seed Project")) {
      $owned = @($toolRows | Where-Object Tool -eq $tool)
      if (-not $owned.Count) { continue }
      Write-Host $tool
      Rule "-"
      PrintCategoryRows $owned
      Write-Host "Status"
      Write-Host "✓ Successfully Installed"
      Write-Host ""
    }
  }

  $templates = @($script:InstallReport | Where-Object Section -eq "Templates")
  if ($templates.Count) { Section "Templates"; PrintCategoryRows $templates; Write-Host "" }

  $config = @($script:InstallReport | Where-Object Section -eq "Configuration")
  if ($config.Count) { Section "Configuration"; PrintRows $config; Write-Host "" }

  $verification = @($script:InstallReport | Where-Object Section -eq "Verification")
  if ($verification.Count) { Section "Verification" "="; PrintRows $verification; Write-Host "" }
  $verificationIssues = @($verification | Where-Object { $_.Status -eq "warn" -or $_.Category -eq "Verification Issues" })

  function CountCategory([string]$Category) { @(UniqueItems (@($script:InstallReport | Where-Object Category -eq $Category))).Count }
  Section "Summary"
  Write-Host "Files Installed: $(CountCategory "Files Installed")"
  Write-Host "Files Overwritten: $(CountCategory "Files Overwritten")"
  Write-Host "Files Already Current: $(CountCategory "Files Already Current")"
  Write-Host "Files Skipped: $(CountCategory "Files Skipped")"
  Write-Host "Shell Commands Run: $(CountCategory "Shell Commands Run")"
  Write-Host "Configuration Entries Updated: $(CountCategory "Configuration Entries Updated")"
  Write-Host "Verification Issues: $($verificationIssues.Count)"
}

function Show-UninstallReport {
  if ($script:UninstallReport.Count -eq 0) {
    return
  }

  function Rule([string]$Char = "-") { Write-Host ($Char * 50) }
  function Section([string]$Name, [string]$Char = "-") { Write-Host $Name; Rule $Char }
  function Mark([string]$Status) { if ($Status -eq "warn") { return "!" }; return "✓" }
  function UniqueItems($Rows) { @($Rows | ForEach-Object { $_.Item } | Where-Object { $_ } | Select-Object -Unique) }
  function PrintRows($Rows) { foreach ($row in $Rows) { Write-Host "$(Mark $row.Status) $($row.Item)" } }

  $instruction = @($script:UninstallReport | Where-Object Section -eq "Instruction Files")
  if ($instruction.Count) { Section "Instruction Files"; PrintRows $instruction; Write-Host "" }

  $toolRows = @($script:UninstallReport | Where-Object Section -eq "Skills and Plugins")
  if ($toolRows.Count) {
    Section "Skills and Plugins" "="
    foreach ($tool in @("Caveman", "RTK", "Optimize-AI", "Seed Project")) {
      $owned = @($toolRows | Where-Object Tool -eq $tool)
      if (-not $owned.Count) { continue }
      Write-Host $tool
      Rule "-"
      $removedDirs = @(UniqueItems (@($owned | Where-Object Category -eq "Directories Removed")))
      foreach ($category in @("Directories Removed", "Files Removed", "Symlinks Removed", "Shell Commands Removed", "Aliases Removed", "PATH Entries Removed", "Environment Variables Removed", "Configuration Entries Removed")) {
        $entries = @($owned | Where-Object Category -eq $category)
        if (-not $entries.Count) { continue }
        if ($category -eq "Files Removed" -and $removedDirs.Count) {
          $entries = @($entries | Where-Object {
            $file = $_.Item
            -not @($removedDirs | Where-Object {
              $dir = $_.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
              $file.StartsWith($dir + [IO.Path]::DirectorySeparatorChar) -or $file.StartsWith($dir + [IO.Path]::AltDirectorySeparatorChar)
            }).Count
          })
          if (-not $entries.Count) { continue }
        }
        $items = UniqueItems $entries
        Write-Host "$category ($($items.Count))"
        foreach ($item in $items) { Write-Host "✓ $item" }
      }
      Write-Host "Status"
      Write-Host "✓ Successfully Removed"
      Write-Host ""
    }
  }

  $templates = @($script:UninstallReport | Where-Object Section -eq "Templates")
  if ($templates.Count) { Section "Templates"; PrintRows $templates; Write-Host "" }

  $config = @($script:UninstallReport | Where-Object Section -eq "Configuration")
  if ($config.Count) { Section "Configuration"; PrintRows $config; Write-Host "" }

  $verification = @($script:UninstallReport | Where-Object Section -eq "Verification")
  $tools = @($toolRows | ForEach-Object { $_.Tool } | Where-Object { $_ } | Select-Object -Unique)
  if ($tools.Count -or $verification.Count) {
    Section "Verification" "="
    foreach ($tool in $tools) {
      $issues = @($verification | Where-Object Tool -eq $tool)
      Write-Host $tool
      if (-not $issues.Count) {
        Write-Host "✓ No managed artifacts remain"
      } else {
        foreach ($issue in $issues) {
          Write-Host "! Remaining Artifact"
          Write-Host "Path:"
          Write-Host $issue.Item
          Write-Host "Reason:"
          Write-Host "Managed artifact still exists after uninstall."
        }
      }
    }
    Write-Host ""
  }

  $preserved = @($script:UninstallReport | Where-Object Section -eq "Preserved Files")
  if ($preserved.Count) {
    Section "Preserved Files"
    foreach ($item in UniqueItems $preserved) { Write-Host "✓ $item" }
    Write-Host ""
  }

  function CountCategory([string]$Category) { @(UniqueItems (@($script:UninstallReport | Where-Object Category -eq $Category))).Count }
  Section "Summary"
  Write-Host "Tools Removed: $($tools.Count)"
  Write-Host "Directories Removed: $(CountCategory "Directories Removed")"
  Write-Host "Files Removed: $(CountCategory "Files Removed")"
  Write-Host "Symlinks Removed: $(CountCategory "Symlinks Removed")"
  Write-Host "Shell Commands Removed: $(CountCategory "Shell Commands Removed")"
  Write-Host "Files Updated: $((CountCategory "Files Updated") + (CountCategory "Configuration Entries Removed"))"
  Write-Host "Files Preserved: $(CountCategory "Files Preserved")"
  Write-Host "Verification Issues: $($verification.Count)"
}

function Invoke-SetupCommand {
  param(
    [string]$FilePath,
    [string[]]$Arguments = @()
  )

  $display = @($FilePath) + $Arguments
  if ($DryRun) {
    Add-InstallReport -Section "Skills and Plugins" -Tool $CurrentTool -Category "Shell Commands Run" -Item "dry-run: $($display -join ' ')"
    return
  }

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "command failed with exit code ${LASTEXITCODE}: $($display -join ' ')"
  }
  Add-InstallReport -Section "Skills and Plugins" -Tool $CurrentTool -Category "Shell Commands Run" -Item ($display -join ' ')
}

function Invoke-OptionalUninstallCommand {
  param(
    [string]$FilePath,
    [string[]]$Arguments = @()
  )

  $display = @($FilePath) + $Arguments
  if ($DryRun) {
    if ($UninstallActive) {
      Add-UninstallReport -Section "Skills and Plugins" -Tool $CurrentTool -Category "Shell Commands Removed" -Item ($display -join ' ')
    } else {
      Write-Setup "dry-run: $($display -join ' ')"
    }
    return
  }

  $output = & $FilePath @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    if ($UninstallActive) {
      Add-UninstallReport -Section "Verification" -Tool $CurrentTool -Category "Verification Issues" -Item ($display -join ' ') -Status "warn"
    } else {
      $output | Write-Host
      Write-Warning "uninstall command failed: $($display -join ' ')"
    }
  } elseif ($UninstallActive) {
    Add-UninstallReport -Section "Skills and Plugins" -Tool $CurrentTool -Category "Shell Commands Removed" -Item ($display -join ' ')
  }
}

function Add-ManifestArtifact {
  param(
    [string]$Type,
    [string]$Component,
    [string]$Ownership,
    [string]$Action,
    [string]$Path,
    [hashtable]$Details = @{}
  )

  if ($DryRun) {
    Add-InstallReport -Section "Configuration" -Tool "" -Category "Configuration Entries Updated" -Item "dry-run: would record manifest artifact $Component $Type $Path"
    return
  }

  $parent = Split-Path -Parent $ManifestPath
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  if (Test-Path $ManifestPath) {
    $raw = Get-Content -Raw $ManifestPath
    $manifest = if ([string]::IsNullOrWhiteSpace($raw)) { [pscustomobject]@{} } else { $raw | ConvertFrom-Json }
  } else {
    $manifest = [pscustomobject]@{}
  }
  if (-not $manifest.PSObject.Properties["schemaVersion"]) { $manifest | Add-Member -MemberType NoteProperty -Name schemaVersion -Value 1 }
  if (-not $manifest.PSObject.Properties["managedBy"]) { $manifest | Add-Member -MemberType NoteProperty -Name managedBy -Value "token-saver-setup" }
  if (-not $manifest.PSObject.Properties["artifacts"]) { $manifest | Add-Member -MemberType NoteProperty -Name artifacts -Value @() }
  $manifest.schemaVersion = 1
  $manifest.managedBy = "token-saver-setup"
  if ($manifest.PSObject.Properties["updatedAt"]) { $manifest.updatedAt = (Get-Date).ToUniversalTime().ToString("o") } else { $manifest | Add-Member -MemberType NoteProperty -Name updatedAt -Value (Get-Date).ToUniversalTime().ToString("o") }

  $detailObject = [pscustomobject]$Details
  $id = @($Component, $Type, $Path, $Details["key"], $Details["command"]) -join ":"
  $artifact = [pscustomobject]@{
    id = $id
    type = $Type
    component = $Component
    ownership = $Ownership
    action = $Action
    path = $Path
    details = $detailObject
    recordedAt = (Get-Date).ToUniversalTime().ToString("o")
  }
  $items = @($manifest.artifacts | Where-Object { $_.id -ne $id })
  $manifest.artifacts = @($items) + $artifact
  $manifest | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $ManifestPath
}

function Add-ManifestDirectory {
  param(
    [string]$Path,
    [string]$Component,
    [string]$Ownership = "installer-created"
  )
  Add-ManifestArtifact -Type "directory" -Component $Component -Ownership $Ownership -Action "created-or-ensured" -Path $Path
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

function Normalize-AiApp {
  param([string]$App)

  $clean = $App.Trim().ToLowerInvariant().Replace("_", "-")
  $clean = ($clean -replace "\s+", "-")
  switch ($clean) {
    "claude" { return "claude" }
    "claude-code" { return "claude" }
    "claudecode" { return "claude" }
    "github-copilot" { return "copilot" }
    "githubcopilot" { return "copilot" }
    "codex" { return "codex" }
    "gemini" { return "gemini" }
    "cursor" { return "cursor" }
    "opencode" { return "opencode" }
    "openclaw" { return "openclaw" }
    "copilot" { return "copilot" }
    default { throw "unsupported AI app: $App" }
  }
}

function Normalize-AiApps {
  param([string]$Value)

  $clean = $Value.Trim().ToLowerInvariant()
  if ($clean -in @("all", "all available", "all-available")) {
    return "claude,codex,gemini,cursor,opencode,openclaw,copilot"
  }

  $items = @()
  foreach ($item in $Value.Split(",")) {
    if ([string]::IsNullOrWhiteSpace($item)) { continue }
    $normalized = Normalize-AiApp -App $item
    if ($items -notcontains $normalized) { $items += $normalized }
  }

  if (-not $items.Count) { return "claude,codex" }
  return ($items -join ",")
}

function Normalize-Asset {
  param([string]$Asset)

  $clean = $Asset.Trim().ToLowerInvariant().Replace("_", "-")
  $clean = ($clean -replace "\s+", "-")
  switch ($clean) {
    "rtk" { return "rtk" }
    "caveman" { return "caveman" }
    "global-instructions" { return "global-instructions" }
    "global" { return "global-instructions" }
    "global-instruction-files" { return "global-instructions" }
    "project-instructions" { return "project-instructions" }
    "project" { return "project-instructions" }
    "project-instruction-files" { return "project-instructions" }
    "project-templates" { return "project-instructions" }
    "seeding" { return "project-instructions" }
    "ai-ignore-boundaries" { return "ai-ignore-boundaries" }
    "ai-ignore" { return "ai-ignore-boundaries" }
    "ignore" { return "ai-ignore-boundaries" }
    "ignore-boundaries" { return "ai-ignore-boundaries" }
    "ignore-optimizer" { return "ai-ignore-boundaries" }
    default { throw "unsupported asset: $Asset" }
  }
}

function Normalize-Assets {
  param([string]$Value)

  $clean = $Value.Trim().ToLowerInvariant()
  if ($clean -in @("all", "all available", "all-available")) {
    return "rtk,caveman,global-instructions,project-instructions,ai-ignore-boundaries"
  }

  $items = @()
  foreach ($item in $Value.Split(",")) {
    if ([string]::IsNullOrWhiteSpace($item)) { continue }
    $normalized = Normalize-Asset -Asset $item
    if ($items -notcontains $normalized) { $items += $normalized }
  }

  if (-not $items.Count) { return "rtk,caveman,global-instructions,project-instructions,ai-ignore-boundaries" }
  return ($items -join ",")
}

function Test-AiApp {
  param([string]$App)
  return @($script:AiApps.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -contains $App
}

function Test-Asset {
  param([string]$Asset)
  return @($script:Assets.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -contains $Asset
}

function Prompt-UninstallComponents {
  $selected = @()

  if (Read-YesNo "Reset all instruction files?" $false) {
    $selected += "reset-global-instructions"
    $selected += "project-instructions"
  } elseif (Read-YesNo "Reset only project instruction sections?" $false) {
    $selected += "project-instructions"
  } else {
    $selected += "global-instructions"
  }

  $components = @(
    'project-templates',
    'seeding',
    'ignore-optimizer',
    'rtk',
    'caveman'
  )
  foreach ($component in $components) {
    if (Read-YesNo "Remove $component?" $false) {
      $selected += $component
    }
  }

  return ($selected -join ',')
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
    [string]$Target,
    [string]$Component = "managed-file"
  )

  if ($DryRun) {
    if ((-not (Test-Path $Target)) -or $Overwrite) {
      Add-InstallFileReport -Component $Component -Category "Files Installed" -Item "dry-run: would install $Target"
    } elseif ((Get-FileHash $Source).Hash -eq (Get-FileHash $Target).Hash) {
      Add-InstallFileReport -Component $Component -Category "Files Already Current" -Item "dry-run: already current $Target"
    } else {
      Add-InstallFileReport -Component $Component -Category "Files Skipped" -Item "dry-run: would skip existing managed file $Target"
    }
    return
  }

  $existed = Test-Path $Target
  $parent = Split-Path -Parent $Target
  New-Item -ItemType Directory -Force -Path $parent | Out-Null

  if ((-not (Test-Path $Target)) -or $Overwrite) {
    Add-ManifestDirectory -Path $parent -Component $Component
    Copy-Item -Force $Source $Target
    if ($existed) {
      Add-ManifestArtifact -Type "file" -Component $Component -Ownership "user-owned" -Action "modified" -Path $Target
    } else {
      Add-ManifestArtifact -Type "file" -Component $Component -Ownership "installer-created" -Action "created" -Path $Target
    }
    Add-InstallFileReport -Component $Component -Category "Files Installed" -Item "installed $Target"
    return
  }

  if ((Get-FileHash $Source).Hash -eq (Get-FileHash $Target).Hash) {
    Add-InstallFileReport -Component $Component -Category "Files Already Current" -Item "already current $Target"
    return
  }

  Add-InstallFileReport -Component $Component -Category "Files Skipped" -Item "skipped existing managed file $Target"
}

function Copy-GlobalInstructionFile {
  param(
    [string]$Source,
    [string]$Target
  )

  if ($DryRun) {
    if (-not (Test-Path $Target)) {
      Add-InstallFileReport -Component "global-instructions" -Category "Files Installed" -Item "dry-run: would install $Target"
    } elseif ($OverwriteGlobalInstructions) {
      Add-InstallFileReport -Component "global-instructions" -Category "Files Overwritten" -Item "dry-run: would overwrite $Target"
    } else {
      Add-InstallFileReport -Component "global-instructions" -Category "Files Skipped" -Item "dry-run: would skip existing global instruction file $Target"
    }
    return
  }

  $existed = Test-Path $Target
  $parent = Split-Path -Parent $Target
  New-Item -ItemType Directory -Force -Path $parent | Out-Null

  if (-not (Test-Path $Target)) {
    Add-ManifestDirectory -Path $parent -Component "global-instructions"
    Copy-Item -Force $Source $Target
    Add-ManifestArtifact -Type "global_instruction_file" -Component "global-instructions" -Ownership "installer-created" -Action "created" -Path $Target
    Add-InstallFileReport -Component "global-instructions" -Category "Files Installed" -Item "installed $Target"
    return
  }

  if ($OverwriteGlobalInstructions) {
    Add-ManifestDirectory -Path $parent -Component "global-instructions"
    Copy-Item -Force $Source $Target
    if ($existed) {
      Add-ManifestArtifact -Type "global_instruction_file" -Component "global-instructions" -Ownership "user-owned" -Action "modified" -Path $Target
    } else {
      Add-ManifestArtifact -Type "global_instruction_file" -Component "global-instructions" -Ownership "installer-created" -Action "created" -Path $Target
    }
    Add-InstallFileReport -Component "global-instructions" -Category "Files Overwritten" -Item "overwrote $Target"
    return
  }

  Add-InstallFileReport -Component "global-instructions" -Category "Files Skipped" -Item "skipped existing global instruction file $Target"
}

function Copy-ProjectTemplateFile {
  param(
    [string]$Source,
    [string]$Target
  )

  if ($DryRun) {
    if (-not (Test-Path $Target)) {
      Add-InstallFileReport -Component "project-templates" -Category "Files Installed" -Item "dry-run: would install $Target"
    } elseif ($OverwriteProjectTemplates -or $Overwrite) {
      Add-InstallFileReport -Component "project-templates" -Category "Files Overwritten" -Item "dry-run: would overwrite $Target"
    } else {
      Add-InstallFileReport -Component "project-templates" -Category "Files Skipped" -Item "dry-run: would skip existing project instruction template file $Target"
    }
    return
  }

  $existed = Test-Path $Target
  $parent = Split-Path -Parent $Target
  New-Item -ItemType Directory -Force -Path $parent | Out-Null

  if (-not (Test-Path $Target)) {
    Add-ManifestDirectory -Path $parent -Component "project-templates"
    Copy-Item -Force $Source $Target
    Add-ManifestArtifact -Type "project_template_file" -Component "project-templates" -Ownership "installer-created" -Action "created" -Path $Target
    Add-InstallFileReport -Component "project-templates" -Category "Files Installed" -Item "installed $Target"
    return
  }

  if ($OverwriteProjectTemplates -or $Overwrite) {
    Add-ManifestDirectory -Path $parent -Component "project-templates"
    Copy-Item -Force $Source $Target
    if ($existed) {
      Add-ManifestArtifact -Type "project_template_file" -Component "project-templates" -Ownership "user-owned" -Action "modified" -Path $Target
    } else {
      Add-ManifestArtifact -Type "project_template_file" -Component "project-templates" -Ownership "installer-created" -Action "created" -Path $Target
    }
    Add-InstallFileReport -Component "project-templates" -Category "Files Overwritten" -Item "overwrote $Target"
    return
  }

  Add-InstallFileReport -Component "project-templates" -Category "Files Skipped" -Item "skipped existing project instruction template file $Target"
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
    Copy-ManagedFile -Source $temp -Target $Target -Component "seeding"
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
    Add-InstallReport -Section "Skills and Plugins" -Tool "Seed Project" -Category "Configuration Entries Updated" -Item "dry-run: would ensure Claude SessionStart hook in $settingsPath"
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
    Add-InstallReport -Section "Skills and Plugins" -Tool "Seed Project" -Category "Configuration Entries Updated" -Item "already has SessionStart hook in $settingsPath"
    return
  }

  $sessionStart = @($data.hooks.SessionStart)
  $sessionStart += [pscustomobject]@{ hooks = @([pscustomobject]$hook) }
  $data.hooks.SessionStart = $sessionStart
  $data | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $settingsPath
  Add-InstallReport -Section "Skills and Plugins" -Tool "Seed Project" -Category "Configuration Entries Updated" -Item "added SessionStart hook to $settingsPath"
  Add-ManifestArtifact -Type "settings_entry" -Component "seeding" -Ownership "user-owned" -Action "ensured" -Path $settingsPath -Details @{ key = "hooks.SessionStart"; command = "seed-project-instructions.ps1" }
}

function Ensure-RtkClaudeHook {
  $settingsPath = Join-Path $HomeDir ".claude/settings.json"
  $command = "rtk hook claude"

  if ($SkipRtk -or -not (Test-RtkAgentEnabled "claude")) {
    return
  }

  $details = @{
    key = "hooks.PreToolUse"
    command = $command
    managedEntry = "RTK Claude hook"
    uninstallBehavior = "remove only the RTK hook entry, preserve the file"
  }

  if ($DryRun) {
    Add-InstallReport -Section "Skills and Plugins" -Tool "RTK" -Category "Configuration Entries Updated" -Item "dry-run: would ensure RTK Claude hook in $settingsPath"
    Add-ManifestArtifact -Type "settings_entry" -Component "rtk" -Ownership "user-owned" -Action "added" -Path $settingsPath -Details $details
    return
  }

  $settingsDir = Split-Path -Parent $settingsPath
  New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null

  $existed = Test-Path $settingsPath
  if ($existed) {
    Copy-Item -Force $settingsPath "$settingsPath.bak"
    $raw = Get-Content -Raw $settingsPath
    try {
      $data = if ([string]::IsNullOrWhiteSpace($raw)) { [pscustomobject]@{} } else { $raw | ConvertFrom-Json }
    } catch {
      throw "invalid JSON in $settingsPath; backup created at $settingsPath.bak"
    }
  } else {
    $data = [pscustomobject]@{}
  }

  if (-not $data.PSObject.Properties["hooks"]) {
    $data | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{})
  }
  if (-not $data.hooks.PSObject.Properties["PreToolUse"] -or -not ($data.hooks.PreToolUse -is [array])) {
    if ($data.hooks.PSObject.Properties["PreToolUse"]) {
      $data.hooks.PreToolUse = @()
    } else {
      $data.hooks | Add-Member -MemberType NoteProperty -Name PreToolUse -Value @()
    }
  }

  $alreadyExists = $false
  $bashEntry = $null
  foreach ($entry in @($data.hooks.PreToolUse)) {
    if ($entry.matcher -eq "Bash" -and -not $bashEntry) {
      $bashEntry = $entry
    }
    foreach ($existing in @($entry.hooks)) {
      if ($existing.type -eq "command" -and $existing.command -eq $command) {
        $alreadyExists = $true
      }
    }
  }

  if ($alreadyExists) {
    Add-InstallReport -Section "Skills and Plugins" -Tool "RTK" -Category "Configuration Entries Updated" -Item "already configured RTK Claude hook in $settingsPath"
    Add-ManifestArtifact -Type "settings_entry" -Component "rtk" -Ownership "user-owned" -Action "already_existed" -Path $settingsPath -Details $details
    return
  }

  if (-not $bashEntry) {
    $bashEntry = [pscustomobject]@{ matcher = "Bash"; hooks = @() }
    $data.hooks.PreToolUse = @($data.hooks.PreToolUse) + $bashEntry
  }
  if (-not ($bashEntry.PSObject.Properties["hooks"]) -or -not ($bashEntry.hooks -is [array])) {
    if ($bashEntry.PSObject.Properties["hooks"]) {
      $bashEntry.hooks = @()
    } else {
      $bashEntry | Add-Member -MemberType NoteProperty -Name hooks -Value @()
    }
  }
  $bashEntry.hooks = @($bashEntry.hooks) + ([pscustomobject]@{ type = "command"; command = $command })

  $json = $data | ConvertTo-Json -Depth 20
  $null = $json | ConvertFrom-Json
  $temp = "$settingsPath.tmp.$PID"
  Set-Content -Encoding UTF8 -Path $temp -Value $json
  Move-Item -Force $temp $settingsPath

  Add-InstallReport -Section "Skills and Plugins" -Tool "RTK" -Category "Configuration Entries Updated" -Item "Registered Claude Code hook"
  Add-InstallReport -Section "Skills and Plugins" -Tool "RTK" -Category "Configuration Entries Updated" -Item "Updated $settingsPath"
  Add-ManifestArtifact -Type "settings_entry" -Component "rtk" -Ownership "user-owned" -Action "added" -Path $settingsPath -Details $details
}

function Install-RtkBinary {
  if (Get-Command rtk -ErrorAction SilentlyContinue) {
    Add-InstallReport -Section "Skills and Plugins" -Tool "RTK" -Category "Files Already Current" -Item "rtk already installed: $((Get-Command rtk).Source)"
    return
  }

  $binDir = Join-Path $HomeDir ".local/bin"
  $zipPath = Join-Path ([IO.Path]::GetTempPath()) "rtk-windows.zip"
  $extractDir = Join-Path ([IO.Path]::GetTempPath()) ("rtk-windows-" + [Guid]::NewGuid().ToString("N"))

  if ($DryRun) {
    Add-InstallReport -Section "Skills and Plugins" -Tool "RTK" -Category "Files Installed" -Item "dry-run: would download the latest rtk-x86_64-pc-windows-msvc.zip release asset"
    Add-InstallReport -Section "Skills and Plugins" -Tool "RTK" -Category "Files Installed" -Item "dry-run: would extract rtk.exe to $binDir"
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
    Add-InstallReport -Section "Skills and Plugins" -Tool "RTK" -Category "Configuration Entries Updated" -Item "added $binDir to user PATH"
  }
}

function Get-RtkInitArgs {
  param([string]$Agent)

  switch ($Agent) {
    "claude" { return @("init", "-g", "--auto-patch") }
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

  return @($AiApps.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -contains $Agent
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

  $script:CurrentTool = "RTK"
  Install-RtkBinary
  if (([Environment]::OSVersion.Platform -eq "Win32NT") -and (-not $env:WSL_DISTRO_NAME)) {
    Write-Warning "On native Windows, RTK installs the binary and config. Transparent shell-hook rewrite requires WSL."
  }

  if (-not (Get-Command rtk -ErrorAction SilentlyContinue) -and -not $DryRun) {
    Write-Warning "rtk is not on PATH after install; skipping rtk init"
    return
  }

  foreach ($agent in $AiApps.Split(",")) {
    $cleanAgent = $agent.Trim()
    if (-not $cleanAgent) {
      continue
    }
    $initArgs = Get-RtkInitArgs -Agent $cleanAgent
    Invoke-SetupCommand -FilePath "rtk" -Arguments $initArgs
    Add-ManifestArtifact -Type "generated_tool_reference" -Component "rtk" -Ownership "external" -Action "initialized" -Path "rtk" -Details @{ agent = $cleanAgent; command = "rtk $($initArgs -join ' ')" }
  }
}

function Verify-RtkSetup {
  if ($SkipRtk) {
    return
  }

  if ($DryRun) {
    Add-InstallReport -Section "Verification" -Tool "RTK" -Category "Verification Checks" -Item "dry-run: would verify RTK binary and assistant instruction wiring"
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

  Add-InstallReport -Section "Verification" -Tool "RTK" -Category "Verification Checks" -Item "verified RTK setup"
}

function Install-CavemanAgentFallbacks {
  $script:CurrentTool = "Caveman"
  foreach ($app in $AiApps.Split(",")) {
    $cleanApp = $app.Trim()
    switch ($cleanApp) {
      "claude" {
        Invoke-SetupCommand -FilePath "claude" -Arguments @("plugin", "marketplace", "add", "JuliusBrussee/caveman")
        Invoke-SetupCommand -FilePath "claude" -Arguments @("plugin", "install", "caveman@caveman")
      }
      "gemini" {
        Invoke-SetupCommand -FilePath "gemini" -Arguments @("extensions", "install", "https://github.com/JuliusBrussee/caveman")
      }
      "opencode" {
        Invoke-SetupCommand -FilePath "npx" -Arguments @("-y", "github:JuliusBrussee/caveman", "--", "--only", "opencode")
      }
      "openclaw" {
        Invoke-SetupCommand -FilePath "npx" -Arguments @("-y", "github:JuliusBrussee/caveman", "--", "--only", "openclaw")
      }
      "codex" {
        $args = @("skills", "add", "JuliusBrussee/caveman", "-a", "codex")
        if ($NonInteractive) { $args += @("--yes", "--global") }
        Invoke-SetupCommand -FilePath "npx" -Arguments $args
      }
      "cursor" {
        $args = @("skills", "add", "JuliusBrussee/caveman", "-a", "cursor")
        if ($NonInteractive) { $args += @("--yes", "--global") }
        Invoke-SetupCommand -FilePath "npx" -Arguments $args
      }
      "copilot" {
        Invoke-SetupCommand -FilePath "npx" -Arguments @("-y", "github:JuliusBrussee/caveman", "--", "--only", "copilot", "--with-init")
      }
    }
  }
}

function Install-CavemanTool {
  if ($SkipCaveman) {
    return
  }

  $script:CurrentTool = "Caveman"
  if ($DryRun) {
    Add-InstallReport -Section "Skills and Plugins" -Tool "Caveman" -Category "Configuration Entries Updated" -Item "dry-run: would write caveman default mode $CavemanMode"
  } else {
    $configDir = Join-Path $HomeDir ".config/caveman"
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    [pscustomobject]@{ defaultMode = $CavemanMode } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $configDir "config.json")
    Add-InstallReport -Section "Skills and Plugins" -Tool "Caveman" -Category "Configuration Entries Updated" -Item "wrote caveman default mode $CavemanMode"
  }

  Add-ManifestArtifact -Type "file" -Component "caveman" -Ownership "installer-created" -Action "created-or-modified" -Path (Join-Path $HomeDir ".config/caveman/config.json")
  Install-CavemanAgentFallbacks
}

function Install-GlobalInstructionFiles {
  if (Test-AiApp "claude") {
    Copy-GlobalInstructionFile -Source (Join-Path $Root "templates/CLAUDE.global.md") -Target (Join-Path $HomeDir ".claude/CLAUDE.md")
  }
  if (Test-AiApp "codex") {
    Copy-RenderedGlobalInstructionFile -Source (Join-Path $Root "templates/AGENTS.global.md") -Target (Join-Path $HomeDir ".codex/AGENTS.md")
  }
}

function Install-ProjectInstructionFiles {
  if (Test-AiApp "claude") {
    Copy-ProjectTemplateFile -Source (Join-Path $Root "templates/CLAUDE.project-template.md") -Target (Join-Path $HomeDir ".claude/CLAUDE.project-template.md")
  }
  if (Test-AiApp "codex") {
    Copy-ProjectTemplateFile -Source (Join-Path $Root "templates/AGENTS.project-template.md") -Target (Join-Path $HomeDir ".codex/AGENTS.project-template.md")
  }

  Copy-RenderedFile -Source (Join-Path $Root "scripts/seed-project-instructions.ps1") -Target (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.ps1")
  Copy-RenderedFile -Source (Join-Path $Root "scripts/seed-project-instructions.sh") -Target (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.sh")
  if (Test-AiApp "claude") {
    Ensure-ClaudeSessionHook
  }
}

function Install-AiIgnoreBoundaries {
  Copy-ManagedFile -Source (Join-Path $Root "scripts/optimize-ai.ps1") -Target (Join-Path $HomeDir ".agents/scripts/optimize-ai.ps1") -Component "ignore-optimizer"
}

function Test-UninstallComponent {
  param([string]$Component)

  if ([string]::IsNullOrWhiteSpace($UninstallComponents) -or $UninstallComponents -in @("all", "all available", "all-available")) {
    return $true
  }

  return @($UninstallComponents.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -contains $Component
}

function Remove-ManagedPath {
  param([string]$Path)

  $category = if (Test-Path $Path -PathType Container) { "Directories Removed" } else { "Files Removed" }
  if ($DryRun) {
    if ($UninstallActive) {
      Add-UninstallReport -Section "Skills and Plugins" -Tool $CurrentTool -Category $category -Item $Path
    } else {
      Write-Setup "dry-run: would remove $Path"
    }
    return
  }

  if (Test-Path $Path) {
    Remove-Item -Recurse -Force $Path
    if ($UninstallActive) {
      Add-UninstallReport -Section "Skills and Plugins" -Tool $CurrentTool -Category $category -Item $Path
    } else {
      Write-Setup "removed $Path"
    }
  } else {
    if (-not $UninstallActive) {
      Write-Setup "already absent $Path"
    }
  }
}

function Remove-MatchingManagedPaths {
  param([string]$Pattern)

  foreach ($path in Get-ChildItem -Force -Path $Pattern -ErrorAction SilentlyContinue) {
    Remove-ManagedPath -Path $path.FullName
  }
}

function Remove-TemplatePath {
  param([string]$Path)

  if ($DryRun) {
    Add-UninstallReport -Section "Templates" -Tool "" -Category "Files Removed" -Item $Path
    return
  }
  if (Test-Path $Path) {
    Remove-Item -Recurse -Force $Path
    Add-UninstallReport -Section "Templates" -Tool "" -Category "Files Removed" -Item $Path
  }
}

function Remove-MatchingTemplatePaths {
  param([string]$Pattern)

  foreach ($path in Get-ChildItem -Force -Path $Pattern -ErrorAction SilentlyContinue) {
    Remove-TemplatePath -Path $path.FullName
  }
}

function Remove-ProjectInstructionSections {
  if (-not (Test-Path -PathType Container $ProjectScope)) {
    Add-UninstallReport -Section "Verification" -Tool "Project Instructions" -Category "Verification Issues" -Item "$ProjectScope not found" -Status "warn"
    return
  }

  $changed = $false
  foreach ($project in Get-ChildItem -Directory -Path $ProjectScope -ErrorAction SilentlyContinue) {
    if ($project.Name.StartsWith(".")) {
      continue
    }
    foreach ($file in @((Join-Path $project.FullName "CLAUDE.md"), (Join-Path $project.FullName "AGENTS.md"))) {
      if (-not (Test-Path -PathType Leaf $file)) {
        continue
      }
      if ($DryRun) {
        Add-UninstallReport -Section "Instruction Files" -Tool "" -Category "Files Updated" -Item "Would remove managed project sections from $file"
        Add-UninstallReport -Section "Preserved Files" -Tool "" -Category "Files Preserved" -Item $file
        $changed = $true
        continue
      }

      $before = Get-Content -Raw $file
      $after = $before
      foreach ($heading in @("Token-Saver File Boundaries", "Development Workflow")) {
        $pattern = "(?s)`n?## $([regex]::Escape($heading))`n.*?(?=`n## |\s*$)"
        $after = [regex]::Replace($after, $pattern, "`n")
      }
      $after = [regex]::Replace($after, "`n{3,}", "`n`n").TrimEnd() + "`n"
      if ($after -ne $before) {
        Set-Content -NoNewline -Encoding UTF8 -Path $file -Value $after
        Add-UninstallReport -Section "Instruction Files" -Tool "" -Category "Files Updated" -Item "Removed managed project sections from $file"
        Add-UninstallReport -Section "Preserved Files" -Tool "" -Category "Files Preserved" -Item $file
        $changed = $true
      }
    }
  }

  if (-not $changed) {
    Add-UninstallReport -Section "Instruction Files" -Tool "" -Category "Files Updated" -Item "No managed project instruction sections found"
  }
}

function Reset-GlobalInstructionFiles {
  foreach ($file in @((Join-Path $HomeDir ".claude/CLAUDE.md"), (Join-Path $HomeDir ".codex/AGENTS.md"))) {
    if ($DryRun) {
      Add-UninstallReport -Section "Instruction Files" -Tool "" -Category "Files Updated" -Item "Would reset $file"
      Add-UninstallReport -Section "Preserved Files" -Tool "" -Category "Files Preserved" -Item $file
      continue
    }
    $parent = Split-Path -Parent $file
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Set-Content -NoNewline -Encoding UTF8 -Path $file -Value ""
    Add-UninstallReport -Section "Instruction Files" -Tool "" -Category "Files Updated" -Item "Reset $file"
    Add-UninstallReport -Section "Preserved Files" -Tool "" -Category "Files Preserved" -Item $file
  }
}

function Get-SelectedUninstallComponents {
  if ([string]::IsNullOrWhiteSpace($UninstallComponents) -or $UninstallComponents -in @("all", "all available", "all-available")) {
    return @("global-instructions", "reset-global-instructions", "project-instructions", "project-templates", "seeding", "ignore-optimizer", "rtk", "caveman")
  }
  return @($UninstallComponents.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Get-Manifest {
  if (-not (Test-Path $ManifestPath)) {
    return $null
  }
  try {
    $raw = Get-Content -Raw $ManifestPath
    if ([string]::IsNullOrWhiteSpace($raw)) {
      return $null
    }
    return $raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Test-ManifestComponent {
  param(
    [object]$Manifest,
    [string]$Component
  )
  return @($Manifest.artifacts | Where-Object { $_.component -eq $Component }).Count -gt 0
}

function Uninstall-ManifestComponent {
  param(
    [object]$Manifest,
    [string]$Component
  )

  foreach ($artifact in @($Manifest.artifacts | Where-Object { $_.component -eq $Component })) {
    switch ($artifact.type) {
      { $_ -in @("file", "global_instruction_file", "project_template_file") } {
        if ($Component -eq "global-instructions") {
          Add-UninstallReport -Section "Instruction Files" -Tool "" -Category "Files Updated" -Item "Preserved $(Split-Path -Leaf $artifact.path)"
          Add-UninstallReport -Section "Preserved Files" -Tool "" -Category "Files Preserved" -Item $artifact.path
        } elseif ($artifact.ownership -eq "installer-created") {
          if ($Component -eq "project-templates") {
            Remove-TemplatePath -Path $artifact.path
          } else {
            $script:CurrentTool = Get-ToolName $Component
            Remove-ManagedPath -Path $artifact.path
          }
        } else {
          Add-UninstallReport -Section "Preserved Files" -Tool "" -Category "Files Preserved" -Item $artifact.path
        }
      }
      "directory" {
        continue
      }
      "settings_entry" {
        if ($Component -eq "seeding") { Remove-ClaudeSeedHook }
        if ($Component -eq "rtk") { Remove-RtkClaudeHook }
        if ($Component -eq "caveman") { Remove-CavemanClaudeSettings }
      }
      "generated_tool_reference" {
        if ($Component -eq "rtk") { Uninstall-RtkComponents }
        if ($Component -eq "caveman") { Uninstall-CavemanComponents }
      }
    }
  }
}

function Remove-ClaudeSeedHook {
  $settingsPath = Join-Path $HomeDir ".claude/settings.json"

  if ($DryRun) {
    if ($UninstallActive) {
      Add-UninstallReport -Section "Skills and Plugins" -Tool "Seed Project" -Category "Configuration Entries Removed" -Item "$settingsPath hooks.SessionStart"
    } else {
      Write-Setup "dry-run: would remove token-saver SessionStart hooks from $settingsPath"
    }
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
  Add-UninstallReport -Section "Skills and Plugins" -Tool "Seed Project" -Category "Configuration Entries Removed" -Item "$settingsPath hooks.SessionStart"
}

function Remove-RtkClaudeHook {
  $settingsPath = Join-Path $HomeDir ".claude/settings.json"

  if ($DryRun) {
    if ($UninstallActive) {
      Add-UninstallReport -Section "Skills and Plugins" -Tool "RTK" -Category "Configuration Entries Removed" -Item "$settingsPath hooks.PreToolUse rtk hook claude"
    } else {
      Write-Setup "dry-run: would remove RTK Claude hook from $settingsPath"
    }
    return
  }
  if (-not (Test-Path $settingsPath)) {
    return
  }

  $raw = Get-Content -Raw $settingsPath
  try {
    $data = if ([string]::IsNullOrWhiteSpace($raw)) { [pscustomobject]@{} } else { $raw | ConvertFrom-Json }
  } catch {
    Copy-Item -Force $settingsPath "$settingsPath.bak"
    throw "invalid JSON in $settingsPath; backup created at $settingsPath.bak"
  }

  if ($data.PSObject.Properties["hooks"] -and $data.hooks.PSObject.Properties["PreToolUse"]) {
    $entries = @()
    foreach ($entry in @($data.hooks.PreToolUse)) {
      $hooks = @($entry.hooks | Where-Object { -not ($_.type -eq "command" -and $_.command -eq "rtk hook claude") })
      if ($hooks.Count -gt 0) {
        $entry.hooks = $hooks
        $entries += $entry
      }
    }
    $data.hooks.PreToolUse = $entries
  }

  $json = $data | ConvertTo-Json -Depth 20
  $null = $json | ConvertFrom-Json
  $temp = "$settingsPath.tmp.$PID"
  Set-Content -Encoding UTF8 -Path $temp -Value $json
  Move-Item -Force $temp $settingsPath
  Add-UninstallReport -Section "Skills and Plugins" -Tool "RTK" -Category "Configuration Entries Removed" -Item "$settingsPath hooks.PreToolUse rtk hook claude"
}

function Remove-CavemanClaudeSettings {
  $settingsPath = Join-Path $HomeDir ".claude/settings.json"

  if ($DryRun) {
    if ($UninstallActive) {
      Add-UninstallReport -Section "Skills and Plugins" -Tool "Caveman" -Category "Configuration Entries Removed" -Item "$settingsPath Caveman entries"
    } else {
      Write-Setup "dry-run: would remove Caveman entries from $settingsPath"
    }
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
        $hooks = @($entry.hooks | Where-Object { ($_ | ConvertTo-Json -Depth 20) -notmatch "caveman|cavecrew" })
        if ($hooks.Count -gt 0) {
          $entry.hooks = $hooks
          $entries += $entry
        }
      }
      $data.hooks.$hookName = $entries
    }
  }
  if ($data.PSObject.Properties["statusLine"] -and (($data.statusLine | ConvertTo-Json -Depth 20) -match "caveman|cavecrew")) {
    $data.PSObject.Properties.Remove("statusLine")
  }
  foreach ($prop in @("mcpServers", "plugins", "enabledPlugins")) {
    if ($data.PSObject.Properties[$prop]) {
      foreach ($name in @($data.$prop.PSObject.Properties.Name)) {
        $value = $data.$prop.$name | ConvertTo-Json -Depth 20
        if ($name -match "caveman|cavecrew" -or $value -match "caveman|cavecrew") {
          $data.$prop.PSObject.Properties.Remove($name)
        }
      }
    }
  }
  $data | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $settingsPath
  Add-UninstallReport -Section "Skills and Plugins" -Tool "Caveman" -Category "Configuration Entries Removed" -Item "$settingsPath Caveman entries"
}

function Remove-CavemanCodexConfig {
  $configPath = Join-Path $HomeDir ".codex/config.toml"

  if ($DryRun) {
    if ($UninstallActive) {
      Add-UninstallReport -Section "Skills and Plugins" -Tool "Caveman" -Category "Configuration Entries Removed" -Item "$configPath Caveman entries"
    } else {
      Write-Setup "dry-run: would remove known Caveman entries from $configPath"
    }
    return
  }
  if (-not (Test-Path $configPath)) {
    return
  }

  $out = New-Object System.Collections.Generic.List[string]
  $skip = $false
  foreach ($line in Get-Content $configPath) {
    if ($line -eq "[mcp_servers.fs_shrunk]" -or $line -like "[hooks.state.*caveman*" -or $line -like "[hooks.state.*cavecrew*") {
      $skip = $true
      continue
    }
    if ($line.StartsWith("[") -and $skip) {
      $skip = $false
    }
    if ($skip) {
      continue
    }
    if ($line -match "caveman|cavecrew|mcps") {
      continue
    }
    $out.Add($line)
  }
  Set-Content -Encoding UTF8 -Path $configPath -Value $out
  Add-UninstallReport -Section "Skills and Plugins" -Tool "Caveman" -Category "Configuration Entries Removed" -Item "$configPath Caveman entries"
}

function Uninstall-RtkComponents {
  $script:CurrentTool = "RTK"
  Detect-RtkAgents
  foreach ($agent in $RtkAgents.Split(",")) {
    $cleanAgent = $agent.Trim()
    if (-not $cleanAgent) {
      continue
    }
    if ((Get-Command rtk -ErrorAction SilentlyContinue) -or $DryRun) {
      $args = @("init", "--uninstall") + @((Get-RtkInitArgs -Agent $cleanAgent)[1..((Get-RtkInitArgs -Agent $cleanAgent).Count - 1)])
      Invoke-OptionalUninstallCommand -FilePath "rtk" -Arguments $args
    }
  }
  Remove-RtkClaudeHook
  Remove-ManagedPath -Path (Join-Path $HomeDir ".codex/RTK.md")
  Remove-ManagedPath -Path (Join-Path $HomeDir ".claude/RTK.md")
  Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/rules/antigravity-rtk-rules.md")
  Remove-MatchingManagedPaths -Pattern (Join-Path $HomeDir ".agents/rules/*rtk*")
}

function Uninstall-CavemanComponents {
  $script:CurrentTool = "Caveman"
  if ((Get-Command npx -ErrorAction SilentlyContinue) -or $DryRun) {
    Invoke-OptionalUninstallCommand -FilePath "npx" -Arguments @("-y", "github:JuliusBrussee/caveman", "--", "--uninstall", "--non-interactive")
    Invoke-OptionalUninstallCommand -FilePath "npx" -Arguments @("skills", "remove", "JuliusBrussee/caveman", "--all")
  } else {
    Add-UninstallReport -Section "Verification" -Tool "Caveman" -Category "Verification Issues" -Item "npx not found; skipped external uninstall" -Status "warn"
  }
  if ((Get-Command gemini -ErrorAction SilentlyContinue) -or $DryRun) {
    Invoke-OptionalUninstallCommand -FilePath "gemini" -Arguments @("extensions", "uninstall", "caveman")
  }
  Remove-ManagedPath -Path (Join-Path $HomeDir ".config/caveman/config.json")
  Remove-ManagedPath -Path (Join-Path $HomeDir ".config/caveman")
  Remove-ManagedPath -Path (Join-Path $HomeDir ".claude/plugins/cache/caveman")
  Remove-ManagedPath -Path (Join-Path $HomeDir ".claude/plugins/marketplaces/caveman")
  foreach ($skill in @("caveman", "caveman-help", "caveman-review", "caveman-compress", "caveman-stats", "caveman-commit")) {
    Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/skills/$skill")
    Remove-ManagedPath -Path (Join-Path $HomeDir ".claude/skills/$skill")
  }
  Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/skills/cavecrew")
  Remove-ManagedPath -Path (Join-Path $HomeDir ".claude/skills/cavecrew")
  Remove-MatchingManagedPaths -Pattern (Join-Path $HomeDir ".agents/skills/*cavecrew*")
  Remove-MatchingManagedPaths -Pattern (Join-Path $HomeDir ".claude/skills/*cavecrew*")
  Remove-MatchingManagedPaths -Pattern (Join-Path $HomeDir ".claude/projects/*caveman*")
  Remove-CavemanClaudeSettings
  Remove-CavemanCodexConfig
}

function Invoke-Uninstall {
  if ([string]::IsNullOrWhiteSpace($script:UninstallComponents) -or $script:UninstallComponents -in @("all", "all available", "all-available")) {
    $script:UninstallComponents = "all available"
  }
  $manifest = Get-Manifest
  if (-not $manifest) {
    Add-UninstallReport -Section "Configuration" -Tool "" -Category "Configuration Entries Removed" -Item "Install manifest missing or unreadable; used legacy cleanup fallback" -Status "warn"
    Invoke-LegacyUninstall
    return
  }

  $usedManifest = $false
  $components = Get-SelectedUninstallComponents
  $total = $components.Count
  $current = 0
  foreach ($component in $components) {
    $current = $current + 1
    Write-StepProgress -Phase "Uninstall" -Current $current -Total $total -Message $component
    $script:CurrentTool = Get-ToolName $component
    if (Test-ManifestComponent -Manifest $manifest -Component $component) {
      $usedManifest = $true
      Uninstall-ManifestComponent -Manifest $manifest -Component $component
    } else {
      Add-UninstallReport -Section "Configuration" -Tool "" -Category "Configuration Entries Removed" -Item "Manifest missing $component records; used legacy fallback" -Status "warn"
      $oldComponents = $script:UninstallComponents
      $script:UninstallComponents = $component
      Invoke-LegacyUninstall
      $script:UninstallComponents = $oldComponents
    }
  }
  if ($usedManifest) {
    Add-UninstallReport -Section "Configuration" -Tool "" -Category "Configuration Entries Removed" -Item "Used install manifest $ManifestPath"
  }
}

function Invoke-LegacyUninstall {
  $components = Get-SelectedUninstallComponents
  $total = $components.Count
  $current = 0
  if (Test-UninstallComponent "global-instructions") {
    $current = $current + 1
    Write-StepProgress -Phase "Uninstall" -Current $current -Total $total -Message "global-instructions"
    Add-UninstallReport -Section "Instruction Files" -Tool "" -Category "Files Updated" -Item "Preserved CLAUDE.md"
    Add-UninstallReport -Section "Instruction Files" -Tool "" -Category "Files Updated" -Item "Preserved AGENTS.md"
    Add-UninstallReport -Section "Preserved Files" -Tool "" -Category "Files Preserved" -Item (Join-Path $HomeDir ".claude/CLAUDE.md")
    Add-UninstallReport -Section "Preserved Files" -Tool "" -Category "Files Preserved" -Item (Join-Path $HomeDir ".codex/AGENTS.md")
  }
  if (Test-UninstallComponent "reset-global-instructions") {
    $current = $current + 1
    Write-StepProgress -Phase "Uninstall" -Current $current -Total $total -Message "reset-global-instructions"
    Reset-GlobalInstructionFiles
  }
  if (Test-UninstallComponent "project-instructions") {
    $current = $current + 1
    Write-StepProgress -Phase "Uninstall" -Current $current -Total $total -Message "project-instructions"
    Remove-ProjectInstructionSections
  }
  if (Test-UninstallComponent "project-templates") {
    $current = $current + 1
    Write-StepProgress -Phase "Uninstall" -Current $current -Total $total -Message "project-templates"
    Remove-TemplatePath -Path (Join-Path $HomeDir ".claude/CLAUDE.project-template.md")
    Remove-TemplatePath -Path (Join-Path $HomeDir ".codex/AGENTS.project-template.md")
    Remove-MatchingTemplatePaths -Pattern (Join-Path $HomeDir ".claude/CLAUDE.project-template.md.new")
    Remove-MatchingTemplatePaths -Pattern (Join-Path $HomeDir ".codex/AGENTS.project-template.md.new")
  }
  if (Test-UninstallComponent "seeding") {
    $current = $current + 1
    Write-StepProgress -Phase "Uninstall" -Current $current -Total $total -Message "seeding"
    $script:CurrentTool = "Seed Project"
    Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.sh")
    Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.ps1")
    Remove-MatchingManagedPaths -Pattern (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.sh.new")
    Remove-MatchingManagedPaths -Pattern (Join-Path $HomeDir ".agents/scripts/seed-project-instructions.ps1.new")
    Remove-ClaudeSeedHook
  }
  if (Test-UninstallComponent "ignore-optimizer") {
    $current = $current + 1
    Write-StepProgress -Phase "Uninstall" -Current $current -Total $total -Message "ignore-optimizer"
    $script:CurrentTool = "Optimize-AI"
    Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/scripts/optimize-ai.sh")
    Remove-ManagedPath -Path (Join-Path $HomeDir ".agents/scripts/optimize-ai.ps1")
    Remove-MatchingManagedPaths -Pattern (Join-Path $HomeDir ".agents/scripts/optimize-ai.sh.new")
    Remove-MatchingManagedPaths -Pattern (Join-Path $HomeDir ".agents/scripts/optimize-ai.ps1.new")
  }
  if (Test-UninstallComponent "rtk") {
    $current = $current + 1
    Write-StepProgress -Phase "Uninstall" -Current $current -Total $total -Message "rtk"
    Uninstall-RtkComponents
  }
  if (Test-UninstallComponent "caveman") {
    $current = $current + 1
    Write-StepProgress -Phase "Uninstall" -Current $current -Total $total -Message "caveman"
    Uninstall-CavemanComponents
  }
}

if ($Uninstall) {
  $UninstallActive = $true
  if (-not $UninstallComponents -and -not $NonInteractive) {
    $UninstallComponents = Prompt-UninstallComponents
  } elseif (-not $UninstallComponents) {
    $UninstallComponents = "all available"
  }

  if ([string]::IsNullOrWhiteSpace($UninstallComponents)) {
    Write-Setup "no uninstall components selected"
    $global:LASTEXITCODE = 0
    exit 0
  }

  Invoke-Uninstall
  Show-UninstallReport
  $global:LASTEXITCODE = 0
  exit 0
}

$AiApps = Read-TextDefault -Prompt "AI apps to configure" -Default $AiApps
$AiApps = Normalize-AiApps -Value $AiApps
$Assets = Normalize-Assets -Value $Assets
$RtkAgents = $AiApps

$installSteps = 5
$installStep = 0
$InstallActive = $true

if ((Test-Asset "rtk") -and (-not $SkipRtk) -and (Read-YesNo -Prompt "Install RTK for selected AI apps?" -Default $true)) {
  $installStep += 1
  Write-StepProgress -Phase "Install" -Current $installStep -Total $installSteps -Message "RTK initialization"
  Initialize-RtkAgents

  $installStep += 1
  Write-StepProgress -Phase "Install" -Current $installStep -Total $installSteps -Message "RTK Claude hook"
  Ensure-RtkClaudeHook

  $installStep += 1
  Write-StepProgress -Phase "Install" -Current $installStep -Total $installSteps -Message "RTK verification"
  Verify-RtkSetup
} else {
  $SkipRtk = $true
}

if ((Test-Asset "caveman") -and (-not $SkipCaveman) -and (Read-YesNo -Prompt "Install Caveman for selected AI apps?" -Default $true)) {
  if (-not $NonInteractive) {
    $CavemanMode = Read-TextDefault -Prompt "Caveman mode to use ($($CavemanModes -join ','))" -Default $CavemanMode
  }
  Assert-CavemanMode -Mode $CavemanMode
  $installStep += 1
  Write-StepProgress -Phase "Install" -Current $installStep -Total $installSteps -Message "Caveman install"
  Install-CavemanTool
} else {
  $SkipCaveman = $true
}

if ((Test-Asset "global-instructions") -and (Read-YesNo -Prompt "Install global instruction files for selected AI apps?" -Default $true)) {
  if (-not $OverwriteGlobalInstructions) {
    $OverwriteGlobalInstructions = Read-YesNo -Prompt "Overwrite existing global instruction files?" -Default $false
  }
  $installStep += 1
  Write-StepProgress -Phase "Install" -Current $installStep -Total $installSteps -Message "global instructions"
  Install-GlobalInstructionFiles
}

if ((Test-Asset "project-instructions") -and (Read-YesNo -Prompt "Install project instruction files for selected AI apps?" -Default $true)) {
  $ProjectScope = Read-TextDefault -Prompt "Enter project directory for project seeding instructions" -Default $ProjectScope
  if (-not $OverwriteProjectTemplates) {
    $OverwriteProjectTemplates = Read-YesNo -Prompt "Overwrite existing project instruction template files?" -Default $false
  }
  $installStep += 1
  Write-StepProgress -Phase "Install" -Current $installStep -Total $installSteps -Message "project instructions"
  Install-ProjectInstructionFiles
}

if ((Test-Asset "ai-ignore-boundaries") -and (Read-YesNo -Prompt "Install AI ignore boundaries for selected AI apps?" -Default $true)) {
  $installStep += 1
  Write-StepProgress -Phase "Install" -Current $installStep -Total $installSteps -Message "AI ignore boundaries"
  Install-AiIgnoreBoundaries
}

Show-InstallReport
Write-Setup "setup complete"
$global:LASTEXITCODE = 0
