[CmdletBinding()]
param([int]$Port = 8010)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
& (Join-Path $repo '.venv/Scripts/python.exe') (Join-Path $repo 'backend/scripts/run_auth_simulation.py') --port $Port
if ($LASTEXITCODE -ne 0) { throw 'Auth simulation did not start. Check the dedicated test DB and port.' }
