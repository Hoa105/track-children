[CmdletBinding()]
param([ValidateSet('all','backend','flutter','analyze')][string]$Only = 'all', [string]$FlutterSdk = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$python = Join-Path $repo '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Project .venv is missing.' }
Push-Location $repo
try {
    $runnerArgs = @((Join-Path $PSScriptRoot 'full_check_before_commit.py'), '--auth-only', '--only', $Only)
    if ($FlutterSdk) { $runnerArgs += @('--flutter-sdk', $FlutterSdk) }
    & $python @runnerArgs
    if ($LASTEXITCODE -ne 0) { throw 'Full auth checks failed or are incomplete. See the report path above.' }
} finally { Pop-Location }
