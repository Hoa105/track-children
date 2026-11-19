[CmdletBinding()]
param(
    [ValidateSet('backend', 'ai', 'all')][string]$Target = 'all',
    [switch]$BootstrapExisting,
    [switch]$ApproveAuthCompaction,
    [string]$Database = '',
    [string]$Container = '',
    [ValidateRange(1, 3600)][int]$LockTimeoutSeconds = 10,
    [ValidateRange(1, 3600)][int]$StatementTimeoutSeconds = 300
)
$ErrorActionPreference = 'Stop'
$Target = $Target.ToLowerInvariant()
$repo = Split-Path -Parent $PSScriptRoot
$python = Join-Path $repo '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    $python = (Get-Command python -ErrorAction Stop).Source
}
$runnerArgs = @(
    (Join-Path $PSScriptRoot 'migrate_system.py'), '--target', $Target,
    '--lock-timeout', $LockTimeoutSeconds, '--statement-timeout', $StatementTimeoutSeconds
)
if ($BootstrapExisting) { $runnerArgs += '--bootstrap-existing' }
if ($ApproveAuthCompaction) { $runnerArgs += '--approve-auth-compaction' }
if ($Database) { $runnerArgs += @('--database', $Database) }
if ($Container) { $runnerArgs += @('--container', $Container) }
& $python @runnerArgs
if ($LASTEXITCODE -ne 0) {
    throw "System migration failed (exit $LASTEXITCODE). The failing database's batch was rolled back."
}
