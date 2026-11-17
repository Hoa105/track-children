param(
    [switch]$PrepareOnly,
    [int]$Port = 5174,
    [string[]]$FlutterArgs = @()
)

$ErrorActionPreference = 'Stop'
$mobilePath = Join-Path $PSScriptRoot '..\mobile'
Push-Location $mobilePath
try {
    & python tool/prepare_web_sdk.py
    if ($LASTEXITCODE -ne 0) { throw 'Could not prepare the patched Flutter Web SDK.' }
    if (-not $PrepareOnly) {
        $enginePath = Join-Path (Get-Location) '.dart_tool\web_engine\src'
        & flutter "--local-engine-src-path=$enginePath" --local-web-sdk=keyboard_fix `
            run -d chrome --web-port $Port --dart-define=DEMO_MODE=false @FlutterArgs
        if ($LASTEXITCODE -ne 0) { throw 'Flutter Web exited with an error.' }
    }
} finally {
    Pop-Location
}
