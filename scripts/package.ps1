param([string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$archive = Join-Path $OutputDirectory "Hitman-Contracts-Overhaul-$version.zip"
Compress-Archive -Path (Join-Path $repoRoot 'files\*') -DestinationPath $archive -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
try {
    $entries = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($required in @('main.lua', 'hco/config.lua', 'assets/hco/drone-flight-sheet.png')) {
        if ($entries -notcontains $required) { throw "Package root entry missing: $required" }
    }
    if ($entries | Where-Object { $_ -like 'files/*' }) { throw 'Package contains an invalid nested files/ directory.' }
}
finally {
    $zip.Dispose()
}
Write-Output $archive
