$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$main = Join-Path $repoRoot 'files\main.lua'
if (-not (Test-Path -LiteralPath $main)) { throw 'files/main.lua is missing.' }
$luaFiles = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'files') -Filter '*.lua' -Recurse
if ($luaFiles.Count -lt 20) { throw "Unexpected Lua file count: $($luaFiles.Count)" }
$forbidden = $luaFiles | Select-String -Pattern 'C:\\Users\\|Documents\\Codex|AppData\\|steamapps\\common' -ErrorAction SilentlyContinue
if ($forbidden) { throw 'Install payload contains a machine-local path.' }
$forbiddenAssets = @('drone-source-magenta.png','drone-source-alpha.png','faction-insignia-source-green.png','faction-insignia-alpha.png')
foreach ($name in $forbiddenAssets) {
    if (Test-Path -LiteralPath (Join-Path $repoRoot "files\assets\hco\$name")) { throw "Intermediate source asset leaked into payload: $name" }
}
Write-Output "HCO_VERIFY_PASS lua_files=$($luaFiles.Count)"
