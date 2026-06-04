[CmdletBinding()]
param(
  [string]$Project = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$DryRun = $env:DRY_RUN -eq "1"

$GitignoreBlock = @"
# -- AI Token Bloat Exclusions --
.env
.env.*
*.log
logs/
coverage/
.nyc_output/
dist/
build/
out/
.next/
.nuxt/
node_modules/
vendor/
.venv/
venv/
__pycache__/
package-lock.json
pnpm-lock.yaml
yarn.lock
poetry.lock
*.db
*.sqlite
*.sqlite3
# -- End AI Token Bloat Exclusions --
"@

$CodexExtraBlock = @"
# -- AI-Only Binary and Asset Exclusions --
*.png
*.jpg
*.jpeg
*.gif
*.webp
*.ico
*.pdf
*.zip
*.tar
*.tgz
*.gz
*.7z
*.dmg
*.mp4
*.mov
*.mp3
*.wav
# -- End AI-Only Binary and Asset Exclusions --
"@

$ClaudeSettings = @"
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./package-lock.json)",
      "Read(./pnpm-lock.yaml)",
      "Read(./yarn.lock)",
      "Read(./poetry.lock)",
      "Read(./node_modules/**)",
      "Read(./vendor/**)",
      "Read(./.venv/**)",
      "Read(./venv/**)",
      "Read(./dist/**)",
      "Read(./build/**)",
      "Read(./out/**)",
      "Read(./.next/**)",
      "Read(./.nuxt/**)",
      "Read(./coverage/**)",
      "Read(./.nyc_output/**)",
      "Read(./**/*.log)",
      "Read(./**/*.db)",
      "Read(./**/*.sqlite)",
      "Read(./**/*.sqlite3)"
    ]
  }
}
"@

function Copy-OrNew {
  param(
    [string]$Content,
    [string]$Target
  )

  if ($DryRun) {
    if (-not (Test-Path $Target)) {
      Write-Output "dry-run: would create $Target"
    } elseif ((Get-Content -Raw $Target) -eq $Content) {
      Write-Output "dry-run: already current $Target"
    } else {
      Write-Output "dry-run: would leave $Target unchanged and write $Target.new"
    }
    return
  }

  $parent = Split-Path -Parent $Target
  New-Item -ItemType Directory -Force -Path $parent | Out-Null

  if (-not (Test-Path $Target)) {
    Set-Content -Encoding UTF8 -Path $Target -Value $Content
    Write-Output "created $Target"
    return
  }

  if ((Get-Content -Raw $Target) -eq $Content) {
    Write-Output "already current $Target"
    return
  }

  Set-Content -Encoding UTF8 -Path "$Target.new" -Value $Content
  Write-Output "left existing $Target unchanged; wrote $Target.new"
}

function Get-WithoutBlock {
  param(
    [string]$File,
    [string]$Start,
    [string]$End
  )

  $kept = @()
  $skipping = $false
  if (Test-Path $File) {
    foreach ($line in Get-Content $File) {
      if ($line -eq $Start) {
        $skipping = $true
        continue
      }
      if ($line -eq $End) {
        $skipping = $false
        continue
      }
      if (-not $skipping) {
        $kept += $line
      }
    }
  }

  $content = ($kept -join [Environment]::NewLine)
  if ($content) {
    $content += [Environment]::NewLine
  }
  return $content
}

if (-not (Test-Path -PathType Container $Project)) {
  exit 0
}

$gitignore = Join-Path $Project ".gitignore"
$gitignoreContent = Get-WithoutBlock -File $gitignore -Start "# -- AI Token Bloat Exclusions --" -End "# -- End AI Token Bloat Exclusions --"
$gitignoreContent += $GitignoreBlock + [Environment]::NewLine
Copy-OrNew -Content $gitignoreContent -Target $gitignore

$codexContent = $gitignoreContent + [Environment]::NewLine + $CodexExtraBlock + [Environment]::NewLine
Copy-OrNew -Content $codexContent -Target (Join-Path $Project ".codexignore")
Copy-OrNew -Content ($ClaudeSettings + [Environment]::NewLine) -Target (Join-Path $Project ".claude/settings.local.json")
