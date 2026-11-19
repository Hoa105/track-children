[CmdletBinding()]
param([string]$DeviceId = '', [ValidateRange(1,3)][int]$Repeat = 1)
$ErrorActionPreference = 'Stop'
$adb = (Get-Command adb -ErrorAction Stop).Source
if (-not $DeviceId) {
    $devices = @(& $adb devices | Select-String '^([^\s]+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
    if ($devices.Count -ne 1) { throw 'Connect one Android device or pass -DeviceId.' }
    $DeviceId = $devices[0]
}
$powerState = (& $adb -s $DeviceId shell dumpsys power | Out-String)
$lockState = (& $adb -s $DeviceId shell dumpsys window policy | Out-String)
if ($powerState -notmatch 'mWakefulness=Awake' -or $lockState -match '(?m)^\s+showing=true') {
    throw 'Unlock the phone and keep its screen on before measuring startup. An off/locked display does not prove an app ANR.'
}
for ($attempt = 1; $attempt -le $Repeat; $attempt++) {
    # Relaunch only: never clear account, preferences, media or shader caches.
    & $adb -s $DeviceId shell am force-stop com.example.track_children | Out-Null
    & $adb -s $DeviceId shell am start -n com.example.track_children/.StartActivity | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not launch the installed application.' }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $ready = $false
    while ($watch.Elapsed.TotalSeconds -lt 25) {
        $appPid = ((& $adb -s $DeviceId shell pidof com.example.track_children) -join '').Trim()
        if ($appPid) {
            $lines = @(& $adb -s $DeviceId logcat -d "--pid=$appPid")
            if ($lines | Select-String 'native_cover_removed') {
                $ready = $true
                break
            }
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw "Attempt $attempt did not complete startup within 25 seconds. Inspect Android ANR and rendering logs." }
    Start-Sleep -Seconds 6
    $alive = ((& $adb -s $DeviceId shell pidof com.example.track_children) -join '').Trim()
    if ($alive -ne $appPid) { throw "Attempt $attempt lost the application process after startup." }
    [pscustomobject]@{
        attempt = $attempt
        processAlive = $true
        startupCompleted = $true
        observedMilliseconds = [int]$watch.Elapsed.TotalMilliseconds
        impellerLogged = [bool]($lines | Select-String 'Using the Impeller rendering backend')
    } | ConvertTo-Json -Compress
}
