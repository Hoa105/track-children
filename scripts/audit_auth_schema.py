"""Read-only auth schema inventory. Does not export rows or connection secrets."""
import json
from pathlib import Path
import sys
import argparse
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
sys.path.insert(0, str(ROOT / 'backend/scripts'))
import psycopg
from psycopg.rows import dict_row
from app.core.config import settings
from prepare_auth_v2_test_db import test_url


def inspect(url):
    with psycopg.connect(url, connect_timeout=5, row_factory=dict_row) as db:
        db.execute('SET TRANSACTION READ ONLY')
        name = db.execute('SELECT current_database() AS name').fetchone()['name']
        columns = db.execute("""SELECT table_schema, table_name, column_name,
            data_type, udt_name, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema IN ('account', 'admin')
            ORDER BY table_schema,table_name,ordinal_position""").fetchall()
        constraints = db.execute("""SELECT n.nspname AS schema, c.relname AS table,
            k.conname AS name, k.contype AS type, pg_get_constraintdef(k.oid) AS definition
            FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
            JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname IN ('account','admin') ORDER BY 1,2,3""").fetchall()
        indexes = db.execute("""SELECT schemaname,tablename,indexname,indexdef
            FROM pg_indexes WHERE schemaname IN ('account','admin')
            ORDER BY schemaname,tablename,indexname""").fetchall()
        functions = db.execute("""SELECT n.nspname AS schema,p.proname AS name,
            p.prosrc LIKE '%%account.auth_codes%%' AS references_legacy_codes
            FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname IN ('account','admin') ORDER BY 1,2""").fetchall()
        return {'database': name, 'columns': columns, 'constraints': constraints,
                'indexes': indexes, 'functions': functions}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / '.runtime/auth-schema/schema.json')
    args = parser.parse_args()
    result = {'checkedAt': datetime.now(timezone.utc).isoformat(),
              'mode': 'READ ONLY; metadata only; no user rows',
              'app': inspect(settings.database_url), 'test': inspect(test_url())}
    output = args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for label in ('app', 'test'):
        tables = sorted({c['table_name'] for c in result[label]['columns'] if c['table_schema'] == 'account'})
        print(label, result[label]['database'], ':', ', '.join(tables))
    print('Saved metadata inventory:', output.name)
