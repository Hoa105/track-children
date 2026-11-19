[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'http://127.0.0.1:8000/api/v1',
    [switch]$Release,
    [switch]$NoInstall,
    [switch]$RequireBackend,
    [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$api = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$api) -or
    $api.Scheme -notin @('http', 'https') -or
    $api.AbsolutePath.TrimEnd('/') -ne '/api/v1' -or
    $api.Query -or $api.Fragment) {
    throw 'ApiBaseUrl must be an HTTP(S) URL ending in /api/v1 (without query or fragment).'
}
Push-Location (Join-Path $root 'mobile')
try {
    $mode = if ($Release) { 'release' } else { 'debug' }
    & flutter build apk "--$mode" --no-pub `
        "--dart-define=DEMO_MODE=false" `
        "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed.' }
    $apk = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-$mode.apk"
    Write-Host "APK: $apk"
    if ($NoInstall) { return }

    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adb) {
        Write-Warning 'adb not found; APK was built but not installed.'
        return
    }
    if (-not $DeviceId) {
        $devices = @(& $adb.Source devices |
            Select-String '^([^\s]+)\s+device$' |
            ForEach-Object { $_.Matches[0].Groups[1].Value })
        if ($devices.Count -eq 1) {
            $DeviceId = $devices[0]
        } elseif ($devices.Count -eq 0) {
            Write-Warning 'No Android device found; APK was built but not installed.'
            return
        } else {
            throw 'Multiple Android devices found. Pass -DeviceId <id>.'
        }
    }
    $isLocalApi = $api.IsLoopback
    if ($isLocalApi -or $RequireBackend) {
        $healthUrl = $api.GetLeftPart([UriPartial]::Authority) + '/health'
        try {
            $health = Invoke-RestMethod $healthUrl -TimeoutSec 10 -ErrorAction Stop
            if ($health.status -ne 'ok') { throw 'Health response status is not ok.' }
            Write-Host "Backend ready: $healthUrl"
        } catch {
            $hint = if ($isLocalApi) {
                "Start the backend from the backend directory: python -m uvicorn app.main:app --env-file .env --host 127.0.0.1 --port $($api.Port)."
            } else {
                'Check ApiBaseUrl and that the backend is running and reachable.'
            }
            $message = "Backend unavailable at $healthUrl. $hint"
            if ($RequireBackend) { throw $message }
            Write-Warning "$message Continuing APK installation; server features will be unavailable until the backend is ready."
        }
    }
    if ($isLocalApi) {
        & $adb.Source -s $DeviceId reverse "tcp:$($api.Port)" "tcp:$($api.Port)"
        if ($LASTEXITCODE -ne 0) {
            throw "Could not forward localhost:$($api.Port) to device $DeviceId."
        }
        Write-Host "ADB reverse: device localhost:$($api.Port) -> host $healthUrl"
    }
    & $adb.Source -s $DeviceId install -r $apk
    if ($LASTEXITCODE -ne 0) { throw "APK install failed on device $DeviceId." }
    & $adb.Source -s $DeviceId shell cmd package install-existing com.example.track_children
    if ($LASTEXITCODE -ne 0) { throw "Could not enable the app for user 0 on device $DeviceId." }
    $installed = & $adb.Source -s $DeviceId shell cmd package list packages com.example.track_children
    if ($LASTEXITCODE -ne 0 -or -not ($installed -match 'com\.example\.track_children')) {
        throw "APK verification failed on device $DeviceId."
    }
    Write-Host "Installed on Android device: $DeviceId"
} finally {
    Pop-Location
}
