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
    Remove-Item Env:HCO_SOURCE_ROOT -ErrorAction SilentlyContinue
}

Write-Output "HCO_TEST_SUITE_PASS suites=$($suites.Count)"
