param([string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$archive = Join-Path $OutputDirectory "Hitman-Contracts-Overhaul-$version.zip"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$payloadRoot = Join-Path $repoRoot 'files'
if (Test-Path -LiteralPath $archive) { [System.IO.File]::Delete($archive) }
$archiveStream = [System.IO.File]::Open($archive, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
$writer = [System.IO.Compression.ZipArchive]::new($archiveStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
try {
    $fixedTimestamp = [System.DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
    foreach ($file in @(Get-ChildItem -LiteralPath $payloadRoot -File -Recurse | Sort-Object { $_.FullName.Substring($payloadRoot.Length) })) {
        $relative = $file.FullName.Substring($payloadRoot.Length).TrimStart('\').Replace('\', '/')
        $entry = $writer.CreateEntry("files/$relative", [System.IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = $fixedTimestamp
        $sourceStream = [System.IO.File]::OpenRead($file.FullName)
        $entryStream = $entry.Open()
        try { $sourceStream.CopyTo($entryStream) }
        finally {
            $entryStream.Dispose()
            $sourceStream.Dispose()
        }
    }
}
finally {
    $writer.Dispose()
    $archiveStream.Dispose()
}

$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
try {
    $entries = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($required in @('files/main.lua', 'files/hco/config.lua', 'files/hco/security/drone_airframe.lua', 'files/hco/security/drone_types.lua', 'files/hco/security/drone_flight.lua', 'files/hco/security/drone_weapons.lua', 'files/assets/hco/drone-roster-atlas.png', 'files/assets/hco/drone-wreck-atlas.png', 'files/assets/hco/drone-rotor-light-loop.wav', 'files/assets/hco/drone-rotor-heavy-loop.wav', 'files/assets/hco/drone-laser-light.wav', 'files/assets/hco/drone-laser-heavy.wav')) {
        if ($entries -notcontains $required) { throw "Package root entry missing: $required" }
    }
}
finally {
    $zip.Dispose()
}
Write-Output $archive
