[CmdletBinding()]
param(
  [switch]$NonInteractive,
  [switch]$DryRun,
  [switch]$Overwrite,
  [switch]$OverwriteGlobalInstructions,
  [switch]$OverwriteProjectTemplates,
  [switch]$Uninstall,
  [string]$UninstallComponents,
  [string]$ProjectScope,
  [switch]$SkipRtk,
  [switch]$SkipCaveman,
  [string]$RtkAgents,
  [string]$CavemanArgs
)

$ErrorActionPreference = "Stop"

$PinnedCommit = "49253c77fb7b32786c6d63e89d38ea763310a25a"
$ArchiveUrl = "https://github.com/elite-guy5/token-saver-setup/archive/$PinnedCommit.zip"
$ArchiveSha256 = "8b08b194bee7efe65e4825bccd52def67b3e47120ec671393bdd84e351f1befa"
$TempDir = Join-Path ([IO.Path]::GetTempPath()) ("token-saver-setup-" + [Guid]::NewGuid().ToString("N"))
$ZipPath = Join-Path $TempDir "token-saver-setup.zip"

if ($DryRun) {
  Write-Host "dry-run: would download $ArchiveUrl"
  Write-Host "dry-run: would run scripts/install.ps1 from the downloaded archive"
  exit 0
}

New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
  Invoke-WebRequest -UseBasicParsing -Uri $ArchiveUrl -OutFile $ZipPath
  $actualSha256 = (Get-FileHash -Algorithm SHA256 -Path $ZipPath).Hash.ToLowerInvariant()
  if ($actualSha256 -ne $ArchiveSha256) {
    throw "setup archive checksum mismatch; expected $ArchiveSha256, actual $actualSha256"
  }
  Expand-Archive -Force -Path $ZipPath -DestinationPath $TempDir
  $RepoDir = Join-Path $TempDir "token-saver-setup-$PinnedCommit"
  $InstallScript = Join-Path $RepoDir "scripts/install.ps1"

  $installArgs = @()
  if ($NonInteractive) { $installArgs += "-NonInteractive" }
  if ($DryRun) { $installArgs += "-DryRun" }
  if ($Overwrite) { $installArgs += "-Overwrite" }
  if ($OverwriteGlobalInstructions) { $installArgs += "-OverwriteGlobalInstructions" }
  if ($OverwriteProjectTemplates) { $installArgs += "-OverwriteProjectTemplates" }
  if ($Uninstall) { $installArgs += "-Uninstall" }
  if ($UninstallComponents) { $installArgs += @("-UninstallComponents", $UninstallComponents) }
  if ($ProjectScope) { $installArgs += @("-ProjectScope", $ProjectScope) }
  if ($SkipRtk) { $installArgs += "-SkipRtk" }
  if ($SkipCaveman) { $installArgs += "-SkipCaveman" }
  if ($RtkAgents) { $installArgs += @("-RtkAgents", $RtkAgents) }
  if ($CavemanArgs) { $installArgs += @("-CavemanArgs", $CavemanArgs) }

  & $InstallScript @installArgs
  if ($LASTEXITCODE -ne 0) {
    throw "installer failed"
  }
  $global:LASTEXITCODE = 0
} finally {
  Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
}
