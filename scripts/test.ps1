param([string]$LovePath)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

if (-not $LovePath) {
    $command = Get-Command 'lovec' -ErrorAction SilentlyContinue
    if ($command) { $LovePath = $command.Source }
}
if (-not $LovePath -or -not (Test-Path -LiteralPath $LovePath -PathType Leaf)) {
    throw 'LÖVE console runner not found. Pass -LovePath C:\path\to\lovec.exe (LÖVE 11.5 recommended).'
}

$env:HCO_SOURCE_ROOT = (Join-Path $repoRoot 'files').Replace('\', '/')
$resolvedLovePath = (Resolve-Path -LiteralPath $LovePath).Path
$windowsHost = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
$knownLovePids = @()

if ($windowsHost) {
    $knownLovePids = @(Get-CimInstance Win32_Process -Filter "Name = 'love.exe' OR Name = 'lovec.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -eq $resolvedLovePath } |
        ForEach-Object { [int]$_.ProcessId })
}

function Stop-HcoTestOrphans {
    if (-not $windowsHost) { return }

    $testRootToken = (Join-Path $repoRoot 'tests').Replace('/', '\')
    $orphans = @(Get-CimInstance Win32_Process -Filter "Name = 'love.exe' OR Name = 'lovec.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ExecutablePath -eq $resolvedLovePath -and
            $knownLovePids -notcontains [int]$_.ProcessId -and
            ($_.CommandLine -like '*hco-*-smoke*' -or $_.CommandLine -like "*$testRootToken*")
        })

    foreach ($process in $orphans) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Output "HCO_TEST_ORPHAN_CLEANED pid=$($process.ProcessId)"
    }
}

$suites = @(
    'hco-boot-smoke',
    'hco-runtime-smoke',
    'hco-drone-smoke',
    'hco-drone-roster-smoke',
    'hco-airframe-smoke',
    'hco-visual-smoke',
    'hco-feedback-smoke'
)

try {
    foreach ($suite in $suites) {
        Write-Output "HCO_TEST_RUN $suite"
        & $LovePath (Join-Path (Join-Path $repoRoot 'tests') $suite)
        if ($LASTEXITCODE -ne 0) { throw "$suite failed with exit code $LASTEXITCODE" }
    }
}
finally {
    Start-Sleep -Milliseconds 150
    Stop-HcoTestOrphans
    Remove-Item Env:HCO_SOURCE_ROOT -ErrorAction SilentlyContinue
}

Write-Output "HCO_TEST_SUITE_PASS suites=$($suites.Count)"
