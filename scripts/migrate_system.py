"""UTF-8, atomic migration batches for the system Docker PostgreSQL databases."""
import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
AUTH_APPROVALS = {
    '025_auth_compact_codes': 'app.auth_025_approved',
    '026_auth_anonymization_compaction_fix': 'app.auth_026_approved',
}
SQL_WORD = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
SQL_DOLLAR = re.compile(r'\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$')


@dataclass(frozen=True)
class Database:
    name: str
    container: str
    database: str
    directory: Path
    baseline: str


DATABASES = {
    'backend': Database('backend', 'track-children-postgres', 'track_children',
                        ROOT / 'backend/migrations', 'account.users'),
    'ai': Database('ai', 'track-children-ai-postgres', 'track_children_ai',
                   ROOT / 'ai-service/migrations', 'ai_kb.kb_documents'),
}


def managed_sql(source):
    """Remove only standalone transaction wrappers outside SQL literals/comments.

    PL/pgSQL dollar bodies and quoted strings remain byte-for-byte unchanged.
    Historical 021/022 own BEGIN/COMMIT; the system runner owns their transaction.
    """
    tokens = []
    parts = []
    start = i = 0

    def statement(end):
        nonlocal start, tokens
        words = [token.upper() for token in tokens]
        if words in (['BEGIN'], ['BEGIN', 'WORK'], ['BEGIN', 'TRANSACTION'],
                     ['START', 'TRANSACTION'], ['COMMIT'], ['COMMIT', 'WORK'], ['END']):
            parts.append('\n-- Transaction boundary managed by system runner.\n')
        elif words and words[0] in ('BEGIN', 'START', 'COMMIT', 'END', 'ROLLBACK', 'ABORT'):
            raise ValueError('Unsupported top-level transaction control in migration')
        else:
            parts.append(source[start:end])
        start = end
        tokens = []

    while i < len(source):
        if source.startswith('--', i):
            end = source.find('\n', i + 2)
            i = len(source) if end < 0 else end + 1
        elif source.startswith('/*', i):
            depth = 1
            i += 2
            while depth and i < len(source):
                if source.startswith('/*', i): depth += 1; i += 2
                elif source.startswith('*/', i): depth -= 1; i += 2
                else: i += 1
            if depth: raise ValueError('Unterminated SQL comment')
        elif source[i] in ("'", '"'):
            quote = source[i]
            escaped = quote == "'" and i > 0 and source[i - 1] in 'eE' and (i < 2 or not source[i - 2].isalnum())
            i += 1
            while i < len(source):
                if escaped and source[i] == '\\': i += 2
                elif source[i] == quote:
                    if i + 1 < len(source) and source[i + 1] == quote: i += 2
                    else: i += 1; break
                else: i += 1
            else: raise ValueError('Unterminated SQL quote')
            tokens.append('<quoted>')
        elif source[i] == '$' and (match := SQL_DOLLAR.match(source, i)):
            tag = match.group()
            end = source.find(tag, i + len(tag))
            if end < 0: raise ValueError('Unterminated SQL dollar body')
            i = end + len(tag)
            tokens.append('<quoted>')
        elif source[i] == ';':
            i += 1
            statement(i)
        elif source[i].isspace(): i += 1
        elif source[i] == '\\' and not source[source.rfind('\n', 0, i) + 1:i].strip():
            raise ValueError('psql commands are not allowed inside migration files')
        elif match := SQL_WORD.match(source, i):
            tokens.append(match.group())
            i += len(match.group())
        else:
            tokens.append(source[i])
            i += 1
    statement(len(source))
    return ''.join(parts)


def build_batch(database, *, approve_auth=False, bootstrap=False, lock_timeout=10,
                statement_timeout=300):
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', database.database):
        raise ValueError('Invalid database name')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', database.container):
        raise ValueError('Invalid container name')
    if not re.fullmatch(r'[a-z_]+\.[a-z_]+', database.baseline):
        raise ValueError('Invalid baseline table')
    if not 1 <= lock_timeout <= 3600 or not 1 <= statement_timeout <= 3600:
        raise ValueError('Timeout must be 1-3600 seconds')
    files = sorted(database.directory.glob('*.sql'), key=lambda path: path.name)
    if not files:
        raise ValueError('No migration SQL files found')
    for path in files:
        if not re.fullmatch(r'[0-9]{3}_[A-Za-z0-9_]+\.sql', path.name):
            raise ValueError('Unsafe migration filename: ' + path.name)
    lines = [
        r'\set ON_ERROR_STOP on',
        'BEGIN;',
        f"SET LOCAL lock_timeout='{lock_timeout}s';",
        f"SET LOCAL statement_timeout='{statement_timeout}s';",
        "SELECT pg_advisory_xact_lock(hashtextextended(current_database() || ':system-migrations',0));",
        'CREATE TABLE IF NOT EXISTS public.schema_migrations '
        '(version varchar(255) PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());',
    ]
    approvals = [p.stem for p in files if database.name == 'backend' and p.stem in AUTH_APPROVALS]
    if approvals and not approve_auth:
        conditions = ' OR '.join(
            "NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version='" + version + "')"
            for version in approvals)
        lines.append("DO $approval$ BEGIN IF " + conditions + " THEN RAISE EXCEPTION "
                     "'Auth compaction requires -ApproveAuthCompaction; no migrations applied'; "
                     "END IF; END $approval$;")
    if approve_auth and database.name == 'backend':
        lines.extend(f"SET LOCAL {setting}='true';" for setting in AUTH_APPROVALS.values())
    if bootstrap:
        lines.extend([
            f"SELECT to_regclass('{database.baseline}') IS NOT NULL AND NOT EXISTS "
            "(SELECT 1 FROM public.schema_migrations WHERE version='001_initial_schema') AS bootstrap_needed \\gset",
            r'\if :bootstrap_needed',
            "INSERT INTO public.schema_migrations(version) VALUES ('001_initial_schema');",
            r'\echo Existing baseline explicitly bootstrapped: 001_initial_schema',
            r'\endif',
        ])
    for path in files:
        lines.extend([
            "SELECT NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version='" + path.stem + "') AS migration_pending \\gset",
            r'\if :migration_pending',
            r'\echo Applying ' + path.stem,
            managed_sql(path.read_text(encoding='utf-8-sig')),
            # A newline also protects this statement from a trailing SQL comment.
            "\nINSERT INTO public.schema_migrations(version) VALUES ('" + path.stem + "');",
            r'\else',
            r'\echo Skipping ' + path.stem,
            r'\endif',
        ])
    lines.extend(['COMMIT;', r'\echo Migration batch committed.'])
    return '\n'.join(lines) + '\n'


def execute_batch(database, batch):
    # Binary stdin avoids Windows PowerShell's default ASCII pipe encoding.
    return subprocess.run(
        ['docker', 'exec', '-i', '-e', 'PGCLIENTENCODING=UTF8',
         '-e', 'PGOPTIONS=-c client_min_messages=warning', database.container,
         'psql', '-X', '-v', 'ON_ERROR_STOP=1', '-U', 'track_children', '-d', database.database],
        input=batch.encode('utf-8'), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=['backend', 'ai', 'all'], default='all')
    parser.add_argument('--bootstrap-existing', action='store_true')
    parser.add_argument('--approve-auth-compaction', action='store_true')
    parser.add_argument('--database')
    parser.add_argument('--container')
    parser.add_argument('--lock-timeout', type=int, default=10)
    parser.add_argument('--statement-timeout', type=int, default=300)
    args = parser.parse_args()
    if args.target == 'all' and (args.database or args.container):
        parser.error('Database/container overrides require a single target')
    if args.target == 'ai' and args.approve_auth_compaction:
        parser.error('Auth approval applies to the backend target only')
    targets = ['backend', 'ai'] if args.target == 'all' else [args.target]
    # Build/validate every plan before contacting either database.
    plans = []
    for name in targets:
        base = DATABASES[name]
        database = Database(name, args.container or base.container, args.database or base.database,
                            base.directory, base.baseline)
        batch = build_batch(database, approve_auth=args.approve_auth_compaction,
                            bootstrap=args.bootstrap_existing, lock_timeout=args.lock_timeout,
                            statement_timeout=args.statement_timeout)
        plans.append((database, batch))
    for database, batch in plans:
        print(f'Migrating {database.name}: {database.container}/{database.database}', flush=True)
        result = execute_batch(database, batch)
        sys.stdout.buffer.write(result.stdout)
        sys.stdout.buffer.flush()
        if result.stderr:
            sys.stderr.buffer.write(result.stderr)
            sys.stderr.buffer.flush()
        if result.returncode:
            print(f'Migration batch failed for {database.name}; its transaction was not committed.', file=sys.stderr)
            return result.returncode
        print(f'{database.name} database is up to date.', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
