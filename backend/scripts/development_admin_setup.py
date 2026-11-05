"""Apply migration 024 and optionally import supplied CDC drafts. Never publish."""
import argparse
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import psycopg2
from psycopg2.extras import RealDictCursor
from app.core.config import settings
from app.features.development import transfer

parser=argparse.ArgumentParser()
parser.add_argument('--apply',action='store_true',help='Apply additive lifecycle migration')
parser.add_argument('--seed',action='store_true',help='Import bundled text as unpublished, inactive drafts')
args=parser.parse_args()
version='024_development_admin_lifecycle'
db=psycopg2.connect(settings.database_url,cursor_factory=RealDictCursor)
with db.cursor() as cur:
 cur.execute('SELECT 1 FROM public.schema_migrations WHERE version=%s',(version,))
 exists=cur.fetchone() is not None
 if not exists:
  if not args.apply:
   print('Migration 024 not applied. Run with --apply; no changes made.');sys.exit(0)
  text=(Path(__file__).resolve().parents[1]/'migrations'/f'{version}.sql').read_text(encoding='utf-8-sig')
  text=text.replace('BEGIN;','').replace('COMMIT;','')
  cur.execute(text)
  cur.execute('INSERT INTO public.schema_migrations(version) VALUES (%s)',(version,))
db.commit()
print('Migration 024 applied or already present.')
if args.seed:
 preview=transfer.preview(db,transfer.bundled())
 if preview['errors']:
  print('Import blocked:',preview['errors']);sys.exit(1)
 print('Draft import:',transfer.commit(db,None,preview['rows'],preview['fingerprint']))
with db.cursor() as cur:
 cur.execute('SELECT kind,count(*) AS total,count(published_revision) AS published FROM development.content_items GROUP BY kind')
 print('Content counts:',[dict(row) for row in cur.fetchall()])
db.close()
