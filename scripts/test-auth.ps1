param([int]$Port = 55439)
$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
$containerName = 'track-children-auth-test'
Push-Location $repoPath
try {
    $existingContainer = docker ps --all --filter "name=^/${containerName}$" --format '{{.Names}}'
    if ($LASTEXITCODE -ne 0) { throw 'Docker is unavailable.' }
    if (-not $existingContainer) {
        docker run --name $containerName --publish "127.0.0.1:${Port}:5432" --env POSTGRES_USER=auth_test --env POSTGRES_PASSWORD=auth_test_local --env POSTGRES_DB=track_children_auth_test --detach postgres:16
        if ($LASTEXITCODE -ne 0) { throw 'Could not create test PostgreSQL container.' }
    } else {
        docker start $containerName | Out-Null
    }
    $databaseReady = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        docker exec $containerName pg_isready -U auth_test -d track_children_auth_test *> $null
        if ($LASTEXITCODE -eq 0) { $databaseReady = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $databaseReady) { throw 'PostgreSQL test database did not become ready.' }
    $previousPythonPath = $env:PYTHONPATH
    $previousTestUrl = $env:AUTH_TEST_DATABASE_URL
    $env:PYTHONPATH = "$repoPath/backend;$previousPythonPath"
    $env:AUTH_TEST_DATABASE_URL = "postgresql://auth_test:auth_test_local@127.0.0.1:${Port}/track_children_auth_test"
    try {
        python -m pytest backend/tests -q
        if ($LASTEXITCODE -ne 0) { throw 'Auth tests failed.' }
    } finally {
        $env:PYTHONPATH = $previousPythonPath
        $env:AUTH_TEST_DATABASE_URL = $previousTestUrl
    }
} finally { Pop-Location }
