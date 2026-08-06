param([string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist' }

$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$configText = Get-Content -LiteralPath (Join-Path $repoRoot 'files\hco\config.lua') -Raw
$match = [regex]::Match($configText, 'VERSION\s*=\s*"([^"]+)"')
if (-not $match.Success) { throw 'Runtime config version is missing.' }
if ($match.Groups[1].Value -ne $version) { throw "VERSION/config mismatch: $version vs $($match.Groups[1].Value)" }

& (Join-Path $PSScriptRoot 'verify.ps1')
$archiveOutput = & (Join-Path $PSScriptRoot 'package.ps1') -OutputDirectory $OutputDirectory
$archive = @($archiveOutput)[-1]
if (-not (Test-Path -LiteralPath $archive)) { throw "Release archive was not created: $archive" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $entries = @{}
    foreach ($entry in $zip.Entries) {
        if (-not [string]::IsNullOrEmpty($entry.Name)) { $entries[$entry.FullName.Replace('\', '/')] = $entry }
    }
    $sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'files') -File -Recurse)
    foreach ($file in $sourceFiles) {
        $relative = 'files/' + $file.FullName.Substring((Join-Path $repoRoot 'files').Length).TrimStart('\').Replace('\', '/')
        $entry = $entries[$relative]
        if (-not $entry) { throw "Archive payload missing: $relative" }
        $sourceStream = [System.IO.File]::OpenRead($file.FullName)
        $entryStream = $entry.Open()
        try {
            $sourceHash = [Convert]::ToHexString($sha.ComputeHash($sourceStream))
            $entryHash = [Convert]::ToHexString($sha.ComputeHash($entryStream))
        }
        finally {
            $sourceStream.Dispose()
            $entryStream.Dispose()
        }
        if ($sourceHash -ne $entryHash) { throw "Archive payload hash mismatch: $relative" }
        $entries.Remove($relative)
    }
    if ($entries.Count -ne 0) { throw "Archive contains unexpected payload: $($entries.Keys -join ', ')" }
}
finally {
    $sha.Dispose()
    $zip.Dispose()
}

$archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Write-Output "HCO_RELEASE_CHECK_PASS version=$version payload=$($sourceFiles.Count) sha256=$archiveHash"
Write-Output $archive
