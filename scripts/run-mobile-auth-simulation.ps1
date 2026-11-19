[CmdletBinding()]
param([string]$DeviceId = '', [int]$Port = 8010, [string]$Account = 'parent01', [switch]$PrepareOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if ($Account -notmatch '^[a-z0-9_-]{1,30}$') { throw 'Account must contain 1-30 lowercase letters, digits, underscores or hyphens.' }
$health = Invoke-RestMethod "http://127.0.0.1:$Port/health" -TimeoutSec 5
if ($health.authSimulation -ne $true) { throw 'Start run-auth-simulation.ps1 first.' }
try {
    # Empty input must fail validation, without creating a user or sending OTP.
    Invoke-WebRequest "http://127.0.0.1:$Port/api/v1/auth/v2/signup/start" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing -TimeoutSec 5 | Out-Null
    throw 'Unexpected signup response.'
} catch {
    if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 422) {
        throw 'Auth simulation signup API is unavailable. Verify backend 8010 before running the app.'
    }
}
$adb = (Get-Command adb -ErrorAction Stop).Source
if (-not $DeviceId) {
    $devices = @(& $adb devices | Select-String '^([^\s]+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
    if ($devices.Count -ne 1) { throw 'Connect one Android device, or pass -DeviceId.' }
    $DeviceId = $devices[0]
}
& $adb -s $DeviceId reverse "tcp:$Port" "tcp:$Port"
if ($LASTEXITCODE -ne 0) { throw 'ADB reverse failed.' }
if ($PrepareOnly) { return }
Push-Location (Join-Path $repo 'mobile')
try {
    & flutter run -d $DeviceId --device-user 0 --debug --no-enable-impeller --dart-define=DEMO_MODE=false --dart-define=AUTH_SIMULATION=true "--dart-define=AUTH_SIMULATION_ACCOUNT=$Account" "--dart-define=API_BASE_URL=http://127.0.0.1:$Port/api/v1"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter auth simulation failed.' }
} finally { Pop-Location }
