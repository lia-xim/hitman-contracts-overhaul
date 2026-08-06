param([string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$archive = Join-Path $OutputDirectory "Hitman-Contracts-Overhaul-$version.zip"
Compress-Archive -LiteralPath (Join-Path $repoRoot 'files') -DestinationPath $archive -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
try {
    $entries = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($required in @('files/main.lua', 'files/hco/config.lua', 'files/hco/security/drone_airframe.lua', 'files/hco/security/drone_types.lua', 'files/hco/security/drone_flight.lua', 'files/hco/security/drone_weapons.lua', 'files/assets/hco/drone-roster-atlas.png', 'files/assets/hco/drone-rotor-light-loop.wav', 'files/assets/hco/drone-rotor-heavy-loop.wav', 'files/assets/hco/drone-laser-light.wav', 'files/assets/hco/drone-laser-heavy.wav')) {
        if ($entries -notcontains $required) { throw "Package root entry missing: $required" }
    }
}
finally {
    $zip.Dispose()
}
Write-Output $archive
