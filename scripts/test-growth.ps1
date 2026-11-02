[CmdletBinding()]
param([string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $env:GROWTH_TEST_DATABASE_URL) {
    $env:GROWTH_TEST_DATABASE_URL = 'postgresql://growth_test:growth_test_local@127.0.0.1:55440/track_children_growth_test'
}
$env:PYTHONPATH = Join-Path $root 'backend'
Push-Location $root
try {
    & $Python -m pytest backend/tests -q
    if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed' }
} finally { Pop-Location }
