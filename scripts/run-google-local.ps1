[CmdletBinding()]
param(
    [string]$DeviceId = '',
    [string]$ApiBaseUrl = 'http://127.0.0.1:8000/api/v1',
    [string]$GoogleServerClientId = '',
    [switch]$BuildOnly,
    [switch]$PrepareOnly,
    [switch]$ConnectUsb,
    [switch]$NoResident
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$python = Join-Path $repoRoot '.venv/Scripts/python.exe'
$definitions = Join-Path $repoRoot '.auth-test-logs/google-dart-defines.json'

if (-not $BuildOnly -and (-not $PrepareOnly -or $ConnectUsb)) {
    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adb) { throw 'adb was not found. Add Android SDK platform-tools to PATH.' }
    if (-not $DeviceId) {
        $devices = @(& $adb.Source devices | Select-String '^([^\s]+)\s+device$' |
            ForEach-Object { $_.Matches[0].Groups[1].Value })
        if ($devices.Count -ne 1) { throw 'Connect one Android device or pass -DeviceId explicitly.' }
        $DeviceId = $devices[0]
    }
    $apiUri = [Uri]$ApiBaseUrl
    if ($apiUri.Host -in @('127.0.0.1', 'localhost', '::1')) {
        $healthUrl = $apiUri.GetLeftPart([UriPartial]::Authority) + '/health'
        try {
            $health = Invoke-RestMethod $healthUrl -TimeoutSec 10
            if ($health.status -ne 'ok') { throw 'Unexpected health response.' }
        } catch {
            throw "Backend is not ready at $healthUrl. Start the backend before running the app."
        }
        & $adb.Source -s $DeviceId reverse "tcp:$($apiUri.Port)" "tcp:$($apiUri.Port)"
        if ($LASTEXITCODE -ne 0) { throw 'Could not connect Android to the local backend through adb reverse.' }
        Write-Host "Android USB backend: $ApiBaseUrl (port forwarding ready)."
    }
}

# Only public Flutter settings are exported. Never copy the backend .env file.
$prepare = @'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
sys.path.insert(0, str(root / 'backend'))
from app.core.config import Settings
s = Settings(_env_file=root / 'backend/.env')
chosen = sys.argv[3] if len(sys.argv) > 3 else ''
if not chosen:
    if len(s.google_client_ids) != 1:
        raise SystemExit('Configure one GOOGLE_CLIENT_IDS entry or pass -GoogleServerClientId explicitly.')
    chosen = s.google_client_ids[0]
if chosen not in s.google_client_ids or not chosen.endswith('.apps.googleusercontent.com'):
    raise SystemExit('Flutter Google client ID must be present in backend GOOGLE_CLIENT_IDS.')
out = root / '.auth-test-logs/google-dart-defines.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({'GOOGLE_SERVER_CLIENT_ID': chosen, 'API_BASE_URL': sys.argv[2], 'DEMO_MODE': False}), encoding='utf-8')
mobile_config = root / 'mobile/lib/config/google_oauth_config.dart'
mobile_config.parent.mkdir(parents=True, exist_ok=True)
mobile_config.write_text(
    '// Public OAuth client ID only. Regenerate with scripts/run-google-local.ps1 -PrepareOnly.\n'
    '// Client secrets must never be placed in the mobile app.\n'
    'const googleOAuthServerClientId = ' + json.dumps(chosen) + ';\n',
    encoding='utf-8',
)
backend_config = root / 'mobile/lib/config/local_backend_config.dart'
backend_config.write_text(
    '// Local development API URL. Regenerate with scripts/run-google-local.ps1 -PrepareOnly.\n'
    'const localMobileApiBaseUrl = ' + json.dumps(sys.argv[2]) + ';\n',
    encoding='utf-8',
)
print('Prepared Google client ID and API URL for Flutter; backend secrets were not exported.')
'@
& $python -c $prepare $repoRoot $ApiBaseUrl $GoogleServerClientId
if ($LASTEXITCODE -ne 0) { throw 'Could not prepare Google configuration.' }
if ($PrepareOnly) { return }

Push-Location (Join-Path $repoRoot 'mobile')
try {
    if ($BuildOnly) {
        & flutter build apk --debug --no-pub "--dart-define-from-file=$definitions" |
            ForEach-Object { $_ -replace '(-Pdart-defines=)\S+', '$1[redacted]' }
    } elseif ($DeviceId) {
        $runArgs = @('run', '-d', $DeviceId, '--device-user', '0', "--dart-define-from-file=$definitions")
        if ($NoResident) { $runArgs += '--no-resident' }
        & flutter @runArgs |
            ForEach-Object { $_ -replace '(-Pdart-defines=)\S+', '$1[redacted]' }
    } else {
        & flutter run "--dart-define-from-file=$definitions" |
            ForEach-Object { $_ -replace '(-Pdart-defines=)\S+', '$1[redacted]' }
    }
    if ($LASTEXITCODE -ne 0) { throw 'Flutter Google run/build failed.' }
} finally {
    Pop-Location
}
