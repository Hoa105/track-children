[CmdletBinding()]
param(
    [string]$DeviceId = '',
    [string]$ApiBaseUrl = 'http://127.0.0.1:8000/api/v1',
    [switch]$PrepareOnly,
    [switch]$NoResident
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$adb = (Get-Command adb -ErrorAction Stop).Source
if (-not $DeviceId) {
    $devices = @(& $adb devices | Select-String '^([^\s]+)\s+device$' |
        ForEach-Object { $_.Matches[0].Groups[1].Value })
    if ($devices.Count -ne 1) { throw 'Connect one Android device or pass -DeviceId.' }
    $DeviceId = $devices[0]
}
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Android devices.' }
$api = [Uri]$ApiBaseUrl
if ($api.Scheme -notin @('http', 'https') -or $api.AbsolutePath.TrimEnd('/') -ne '/api/v1') {
    throw 'ApiBaseUrl must be an HTTP(S) URL ending in /api/v1.'
}
if ($api.Host -in @('127.0.0.1', 'localhost', '::1')) {
    $healthUrl = $api.GetLeftPart([UriPartial]::Authority) + '/health'
    $health = Invoke-RestMethod $healthUrl -TimeoutSec 10
    if ($health.status -ne 'ok') { throw "Backend is not ready at $healthUrl." }
    & $adb -s $DeviceId reverse "tcp:$($api.Port)" "tcp:$($api.Port)"
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure adb reverse.' }
    Write-Host "Android $DeviceId -> $ApiBaseUrl (USB forwarding ready)"
}
if ($PrepareOnly) { return }
Push-Location (Join-Path $repoRoot 'mobile')
try {
    $runArgs = @('run', '-d', $DeviceId, '--device-user', '0',
        '--dart-define=DEMO_MODE=false', "--dart-define=API_BASE_URL=$ApiBaseUrl")
    if ($NoResident) { $runArgs += '--no-resident' }
    & flutter @runArgs
    if ($LASTEXITCODE -ne 0) { throw 'Flutter Android run failed.' }
} finally {
    Pop-Location
}
