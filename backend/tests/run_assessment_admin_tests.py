"""Run assessment regression tests in a new, empty PostgreSQL database."""
import os
from pathlib import Path
import subprocess
import sys
from uuid import uuid4
import psycopg2
from psycopg2 import sql

root=Path(__file__).resolve().parents[2]
name='assessment_admin_test_'+uuid4().hex
base='postgresql://track_children:track_children_dev@localhost:5433/'
admin=psycopg2.connect(base+'postgres',connect_timeout=5);admin.autocommit=True
try:
 with admin.cursor() as cur:cur.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
 with psycopg2.connect(base+name) as db:
  with db.cursor() as cur:
   cur.execute('''CREATE SCHEMA admin;CREATE SCHEMA child;CREATE SCHEMA account;
    CREATE TABLE admin.admin_users(id uuid PRIMARY KEY,full_name text);
    CREATE TABLE child.children(id uuid PRIMARY KEY);
    CREATE TABLE account.users(id uuid PRIMARY KEY);
    CREATE TABLE admin.admin_audit_logs(id bigserial PRIMARY KEY,admin_user_id uuid REFERENCES admin.admin_users(id),
     action text,entity_type text,entity_id text,before_data jsonb,after_data jsonb,created_at timestamptz DEFAULT now());''')
   for prefix in ('021_','023_','024_','025_'):
    cur.execute(next((root/'backend/migrations').glob(prefix+'*.sql')).read_text(encoding='utf-8-sig'))
 env={**os.environ,'ASSESSMENT_TEST_DATABASE_URL':base+name}
 result=subprocess.run([sys.executable,'-m','pytest','backend/tests/test_assessment_admin.py','backend/tests/test_assessment_mobile.py','-q','-p','no:cacheprovider'],cwd=root,env=env)
 sys.exit(result.returncode)
finally:
 with admin.cursor() as cur:
  cur.execute('SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname=%s',(name,))
  cur.execute(sql.SQL('DROP DATABASE IF EXISTS {}').format(sql.Identifier(name)))
 admin.close()
