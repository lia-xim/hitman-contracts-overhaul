param([string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$archive = Join-Path $OutputDirectory "Hitman-Contracts-Overhaul-$version.zip"
Compress-Archive -LiteralPath (Join-Path $repoRoot 'files') -DestinationPath $archive -Force
Write-Output $archive
