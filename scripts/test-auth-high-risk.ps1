[CmdletBinding()]
param([switch]$PrepareOnly, [string]$FlutterSdk = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$python = Join-Path $repo '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Create the project .venv and install backend/requirements.txt first.' }
if (-not $FlutterSdk) {
    $flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
    $FlutterSdk = Split-Path -Parent (Split-Path -Parent $flutterCommand)
}
$runnerArgs = @((Join-Path $PSScriptRoot 'test_auth_high_risk.py'), '--flutter-sdk', $FlutterSdk)
if ($PrepareOnly) { $runnerArgs += '--prepare-only' }
& $python @runnerArgs
if ($LASTEXITCODE -ne 0) { throw "Auth high-risk checks failed or are incomplete (exit $LASTEXITCODE). See the report path above." }
