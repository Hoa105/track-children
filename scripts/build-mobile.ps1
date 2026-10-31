[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'http://127.0.0.1:8000/api/v1',
    [switch]$Release
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $root 'mobile')
try {
    $mode = if ($Release) { 'release' } else { 'debug' }
    & flutter build apk "--$mode" --no-pub `
        "--dart-define=DEMO_MODE=false" `
        "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed.' }
    Write-Host "APK: mobile\build\app\outputs\flutter-apk\app-$mode.apk"
} finally {
    Pop-Location
}
