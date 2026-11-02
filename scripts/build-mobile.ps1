[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'http://127.0.0.1:8000/api/v1',
    [switch]$Release,
    [switch]$NoInstall,
    [string]$DeviceId = ''
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
    $api = [Uri]$ApiBaseUrl
    if ($api.Scheme -notin @('http', 'https') -or
        $api.AbsolutePath.TrimEnd('/') -ne '/api/v1') {
        throw 'ApiBaseUrl must be an HTTP(S) URL ending in /api/v1.'
    }
    if ($api.Host -in @('127.0.0.1', 'localhost', '::1')) {
        $healthUrl = $api.GetLeftPart([UriPartial]::Authority) + '/health'
        $health = Invoke-RestMethod $healthUrl -TimeoutSec 10
        if ($health.status -ne 'ok') { throw "Backend is not ready at $healthUrl." }
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
