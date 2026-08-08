param(
    [string]$GameDirectory = 'C:\Program Files (x86)\Steam\steamapps\common\Intravenous 2',
    [string]$FolderName = 'Hitman-Contracts-Overhaul'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$sourceFilesRoot = Join-Path $repoRoot 'files'
$previewSource = Join-Path $repoRoot 'workshop\preview.jpg'
$stagingParent = Join-Path $GameDirectory 'mods_staging'
$stagingRoot = Join-Path $stagingParent $FolderName
$stagingFilesRoot = Join-Path $stagingRoot 'files'
$metadataPath = Join-Path $stagingFilesRoot 'metadata'
$previewTarget = Join-Path $stagingRoot 'preview.jpg'

function Assert-ChildPath([string]$Candidate, [string]$Parent) {
    $candidateFull = [System.IO.Path]::GetFullPath($Candidate).TrimEnd('\')
    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\')
    if (-not $candidateFull.StartsWith($parentFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing path outside staging parent: $candidateFull"
    }
}

if (-not (Test-Path -LiteralPath $GameDirectory -PathType Container)) { throw "Game directory not found: $GameDirectory" }
if (-not (Test-Path -LiteralPath (Join-Path $sourceFilesRoot 'main.lua') -PathType Leaf)) { throw 'Repository payload is missing files/main.lua.' }
if (-not (Test-Path -LiteralPath $previewSource -PathType Leaf)) { throw 'Workshop preview is missing.' }

$gameProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -and $_.Path.StartsWith($GameDirectory, [System.StringComparison]::OrdinalIgnoreCase) } catch { $false }
})
if ($gameProcesses.Count -gt 0) { throw 'Close Intravenous 2 before preparing the Workshop staging directory.' }

$previewInfo = Get-Item -LiteralPath $previewSource
if ($previewInfo.Length -gt 1048576) { throw "Workshop preview exceeds the native 1 MiB limit: $($previewInfo.Length) bytes" }

Assert-ChildPath -Candidate $stagingRoot -Parent $stagingParent
New-Item -ItemType Directory -Force -Path $stagingFilesRoot | Out-Null

$metadataBackup = $null
if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
    $metadataBackup = Get-Content -LiteralPath $metadataPath -Raw
}

foreach ($entry in @(Get-ChildItem -LiteralPath $stagingFilesRoot -Force)) {
    if ($entry.Name -ne 'metadata') {
        Assert-ChildPath -Candidate $entry.FullName -Parent $stagingRoot
        Remove-Item -LiteralPath $entry.FullName -Recurse -Force
    }
}

foreach ($sourceEntry in @(Get-ChildItem -LiteralPath $sourceFilesRoot -Force)) {
    Copy-Item -LiteralPath $sourceEntry.FullName -Destination $stagingFilesRoot -Recurse -Force
}
Copy-Item -LiteralPath $previewSource -Destination $previewTarget -Force

if ($null -ne $metadataBackup) {
    Set-Content -LiteralPath $metadataPath -Value $metadataBackup -NoNewline -Encoding UTF8
}

$sourceFiles = @(Get-ChildItem -LiteralPath $sourceFilesRoot -File -Recurse)
$stagedFiles = @(Get-ChildItem -LiteralPath $stagingFilesRoot -File -Recurse | Where-Object { $_.FullName -ne $metadataPath })
if ($sourceFiles.Count -ne $stagedFiles.Count) { throw "Staged payload count mismatch: source=$($sourceFiles.Count), staged=$($stagedFiles.Count)" }

foreach ($sourceFile in $sourceFiles) {
    $relative = $sourceFile.FullName.Substring($sourceFilesRoot.Length).TrimStart('\')
    $stagedFile = Join-Path $stagingFilesRoot $relative
    if (-not (Test-Path -LiteralPath $stagedFile -PathType Leaf)) { throw "Staged payload missing: $relative" }
    $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
    $stagedHash = (Get-FileHash -LiteralPath $stagedFile -Algorithm SHA256).Hash
    if ($sourceHash -ne $stagedHash) { throw "Staged payload hash mismatch: $relative" }
}

$previewHash = (Get-FileHash -LiteralPath $previewTarget -Algorithm SHA256).Hash
$metadataMode = if ($null -ne $metadataBackup) { 'existing-item metadata preserved' } else { 'new Workshop item' }
Write-Output "HCO_WORKSHOP_STAGE_PASS files=$($sourceFiles.Count) preview_bytes=$($previewInfo.Length) mode=$metadataMode"
Write-Output "Staging: $stagingRoot"
Write-Output "Preview SHA256: $previewHash"
Write-Output 'Title: Hitman Contracts Overhaul | HVTs, Drones & Disguises'
Write-Output 'Tags: Gameplay, Objects, Audio, Graphics'
