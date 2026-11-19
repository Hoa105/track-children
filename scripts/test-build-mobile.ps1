# Isolated script regression checks: no Flutter build, device access or HTTP.
$ErrorActionPreference = 'Stop'
$buildScript = Join-Path $PSScriptRoot 'build-mobile.ps1'
$global:buildMobileTestHealthMode = 'offline'
$global:buildMobileTestCommands = [System.Collections.Generic.List[string]]::new()

function flutter {
    $global:buildMobileTestCommands.Add('flutter')
    $global:LASTEXITCODE = 0
}
function Get-Command {
    param([string]$Name, $ErrorAction)
    if ($Name -ne 'adb') { throw "Unexpected command lookup: $Name" }
    return [pscustomobject]@{ Source = 'Invoke-TestAdb' }
}
function Invoke-TestAdb {
    $global:buildMobileTestCommands.Add("adb $args")
    $global:LASTEXITCODE = 0
    if ("$args" -match 'list packages') { 'package:com.example.track_children' }
}
function Invoke-RestMethod {
    param($Uri, $TimeoutSec, $ErrorAction)
    $global:buildMobileTestCommands.Add("health $Uri")
    switch ($global:buildMobileTestHealthMode) {
        'offline' { throw 'Unable to connect to the remote server' }
        'unhealthy' { return @{ status = 'starting' } }
        'ready' { return @{ status = 'ok' } }
    }
}
function Assert-Check([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

foreach ($mode in @('offline', 'unhealthy', 'ready')) {
    $global:buildMobileTestCommands.Clear()
    $global:buildMobileTestHealthMode = $mode
    $warnings = @()
    & $buildScript -DeviceId test-device -WarningVariable warnings -WarningAction SilentlyContinue
    Assert-Check ([bool]($global:buildMobileTestCommands -match 'adb .* reverse tcp:8000 tcp:8000')) 'Missing USB forwarding'
    Assert-Check ([bool]($global:buildMobileTestCommands -match 'adb .* install -r')) "Installation blocked for $mode backend"
    Assert-Check (($warnings.Count -gt 0) -eq ($mode -ne 'ready')) 'Unexpected backend warning state'
}

foreach ($url in @('http://127.0.0.1:8000/api/v1', 'https://api.example.test/api/v1')) {
    $global:buildMobileTestCommands.Clear()
    $global:buildMobileTestHealthMode = 'offline'
    $failed = $false
    try { & $buildScript -DeviceId test-device -ApiBaseUrl $url -RequireBackend }
    catch { $failed = $_.Exception.Message -match 'Backend unavailable' }
    Assert-Check $failed 'RequireBackend must report backend failure'
    Assert-Check (-not ($global:buildMobileTestCommands -match 'adb .* install -r')) 'Installed despite RequireBackend failure'
}

$global:buildMobileTestCommands.Clear()
& $buildScript -NoInstall
Assert-Check ($global:buildMobileTestCommands.Count -eq 1 -and $global:buildMobileTestCommands[0] -eq 'flutter') 'NoInstall accessed backend or device'

$global:buildMobileTestCommands.Clear()
$failed = $false
try { & $buildScript -ApiBaseUrl 'invalid-url' -NoInstall }
catch { $failed = $_.Exception.Message -match 'ApiBaseUrl must' }
Assert-Check $failed 'Invalid URL was accepted'
Assert-Check ($global:buildMobileTestCommands.Count -eq 0) 'Invalid URL triggered a build'
Write-Host 'All 7 build-mobile regression checks passed.'
