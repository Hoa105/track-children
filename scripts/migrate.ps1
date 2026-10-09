[CmdletBinding()]
param(
    [ValidateSet("backend", "ai", "all")]
    [string]$Target = "all",
    [switch]$BootstrapExisting
)

$ErrorActionPreference = "Stop"

$migrations = @{
    backend = @{
        Container = "track-children-postgres"
        Database = "track_children"
        Directory = Join-Path $PSScriptRoot "..\backend\migrations"
        BaselineTable = "account.users"
    }
    ai = @{
        Container = "track-children-ai-postgres"
        Database = "track_children_ai"
        Directory = Join-Path $PSScriptRoot "..\ai-service\migrations"
        BaselineTable = "ai_kb.kb_documents"
    }
}

function Invoke-DatabaseCommand {
    param(
        [hashtable]$Database,
        [string[]]$Arguments
    )

    & docker exec $Database.Container psql -v ON_ERROR_STOP=1 `
        -U track_children -d $Database.Database @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL command failed for database '$($Database.Database)'."
    }
}

function Invoke-Migrations {
    param(
        [string]$Name
    )

    $database = $migrations[$Name]
    Write-Host "Migrating $Name database '$($database.Database)'..."

    Invoke-DatabaseCommand -Database $database -Arguments @(
        "-c",
        "CREATE TABLE IF NOT EXISTS public.schema_migrations (version varchar(255) PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());"
    )

    if ($BootstrapExisting) {
        $hasBaseline = & docker exec $database.Container psql -At -U track_children `
            -d $database.Database -c "SELECT to_regclass('$($database.BaselineTable)') IS NOT NULL;"
        if ($LASTEXITCODE -ne 0) {
            throw "Could not inspect the existing schema for '$Name'."
        }
        if ($hasBaseline -contains "t") {
            $baselineVersion = "001_initial_schema"
            Invoke-DatabaseCommand -Database $database -Arguments @(
                "-c",
                "INSERT INTO public.schema_migrations (version) VALUES ('$baselineVersion') ON CONFLICT (version) DO NOTHING;"
            )
            Write-Host "  Existing schema detected; marked $baselineVersion as applied."
        }
    }

    $files = Get-ChildItem -LiteralPath $database.Directory -Filter "*.sql" -File |
        Sort-Object Name

    foreach ($file in $files) {
        $version = $file.BaseName
        $applied = & docker exec $database.Container psql -At -U track_children `
            -d $database.Database -c "SELECT 1 FROM public.schema_migrations WHERE version = '$version';"
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read migration status for '$version'."
        }

        if ($applied -contains "1") {
            Write-Host "  Skipping $version (already applied)."
            continue
        }

        Write-Host "  Applying $version..."
        Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 |
            & docker exec -i $database.Container psql -v ON_ERROR_STOP=1 -1 `
                -U track_children -d $database.Database
        if ($LASTEXITCODE -ne 0) {
            throw "Migration '$version' failed for database '$($database.Database)'."
        }

        Invoke-DatabaseCommand -Database $database -Arguments @(
            "-c",
            "INSERT INTO public.schema_migrations (version) VALUES ('$version');"
        )
    }

    Write-Host "$Name database is up to date."
}

if ($Target -eq "all" -or $Target -eq "backend") {
    Invoke-Migrations -Name backend
}
if ($Target -eq "all" -or $Target -eq "ai") {
    Invoke-Migrations -Name ai
}
