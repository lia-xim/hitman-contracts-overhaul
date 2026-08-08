param([string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist' }

$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$configText = Get-Content -LiteralPath (Join-Path $repoRoot 'files\hco\config.lua') -Raw
$match = [regex]::Match($configText, 'VERSION\s*=\s*"([^"]+)"')
if (-not $match.Success) { throw 'Runtime config version is missing.' }
if ($match.Groups[1].Value -ne $version) { throw "VERSION/config mismatch: $version vs $($match.Groups[1].Value)" }

$workshopRoot = Join-Path $repoRoot 'workshop'
$workshopTitle = (Get-Content -LiteralPath (Join-Path $workshopRoot 'title.txt') -Raw).Trim()
$workshopDescription = Get-Content -LiteralPath (Join-Path $workshopRoot 'description.txt') -Raw
$workshopDescriptionBytes = [System.Text.Encoding]::UTF8.GetByteCount($workshopDescription)
$workshopTags = @(Get-Content -LiteralPath (Join-Path $workshopRoot 'tags.txt') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$workshopChangeNote = (Get-Content -LiteralPath (Join-Path $workshopRoot 'changenote.txt') -Raw).Trim()
$workshopPreview = Get-Item -LiteralPath (Join-Path $workshopRoot 'preview.jpg')
$allowedTags = @('Gameplay', 'Weapons', 'Levels', 'Graphics', 'Objects', 'Audio', 'Miscellaneous')
if ([string]::IsNullOrWhiteSpace($workshopTitle) -or $workshopTitle.Length -gt 129) { throw "Workshop title must contain 1-129 characters: $($workshopTitle.Length)" }
if ($workshopTags.Count -lt 1) { throw 'At least one Workshop tag is required.' }
foreach ($tag in $workshopTags) {
    if ($allowedTags -notcontains $tag) { throw "Unsupported Workshop tag: $tag" }
}
if ([string]::IsNullOrWhiteSpace($workshopChangeNote)) { throw 'Workshop change note is empty.' }
if ($workshopDescriptionBytes -gt 8000) { throw "Workshop description exceeds Steam's 8000-byte limit: $workshopDescriptionBytes bytes" }
if ($workshopPreview.Length -gt 1048576) { throw "Workshop preview exceeds the native 1 MiB limit: $($workshopPreview.Length) bytes" }
if ($workshopDescription -notmatch [regex]::Escape("[b]$version[/b]")) { throw "Workshop description does not identify current version $version." }
if ($workshopDescription -match 'NEW IN RC42') { throw 'Workshop description still contains the stale RC42 release heading.' }

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
Write-Output "HCO_RELEASE_CHECK_PASS version=$version payload=$($sourceFiles.Count) workshop_tags=$($workshopTags.Count) description_bytes=$workshopDescriptionBytes preview_bytes=$($workshopPreview.Length) sha256=$archiveHash"
Write-Output $archive
