[CmdletBinding()]
param(
  [switch]$NonInteractive,
  [switch]$DryRun,
  [switch]$Overwrite,
  [string]$ProjectScope,
  [switch]$SkipRtk,
  [switch]$SkipCaveman,
  [string]$RtkAgents,
  [string]$CavemanArgs
)

$ErrorActionPreference = "Stop"

$ArchiveUrl = "https://github.com/elite-guy5/token-saver-setup/archive/refs/heads/main.zip"
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
  Expand-Archive -Force -Path $ZipPath -DestinationPath $TempDir
  $RepoDir = Join-Path $TempDir "token-saver-setup-main"
  $InstallScript = Join-Path $RepoDir "scripts/install.ps1"

  $installArgs = @()
  if ($NonInteractive) { $installArgs += "-NonInteractive" }
  if ($DryRun) { $installArgs += "-DryRun" }
  if ($Overwrite) { $installArgs += "-Overwrite" }
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
