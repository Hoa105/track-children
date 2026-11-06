"""Apply migrations 024-025 and optionally import supplied CDC drafts. Never publish."""
import argparse
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import psycopg2
from psycopg2.extras import RealDictCursor
from app.core.config import settings
from app.features.assessment.admin import transfer

parser=argparse.ArgumentParser()
parser.add_argument('--apply',action='store_true',help='Apply lifecycle and assessment schema migrations')
parser.add_argument('--seed',action='store_true',help='Import bundled text as unpublished, inactive drafts')
args=parser.parse_args()
versions=(
 ('024_development_admin_lifecycle','024_assessment_admin_lifecycle.sql'),
 ('025_rename_development_to_assessment','025_rename_schema_to_assessment.sql'),
)
db=psycopg2.connect(settings.database_url,cursor_factory=RealDictCursor)
with db:
 with db.cursor() as cur:
  for version,filename in versions:
   cur.execute('SELECT 1 FROM public.schema_migrations WHERE version=%s',(version,))
   if cur.fetchone() is not None:
    continue
   if not args.apply:
    print(f'Migration {version} not applied. Run with --apply; no changes made.');sys.exit(0)
   text=(Path(__file__).resolve().parents[1]/'migrations'/filename).read_text(encoding='utf-8-sig')
   text=text.replace('BEGIN;','').replace('COMMIT;','')
   cur.execute(text)
   cur.execute('INSERT INTO public.schema_migrations(version) VALUES (%s)',(version,))
print('Migrations 024-025 applied or already present.')
if args.seed:
 preview=transfer.preview(db,transfer.bundled())
 if preview['errors']:
  print('Import blocked:',preview['errors']);sys.exit(1)
 print('Draft import:',transfer.commit(db,None,preview['rows'],preview['fingerprint']))
with db.cursor() as cur:
 cur.execute('SELECT kind,count(*) AS total,count(published_revision) AS published FROM assessment.content_items GROUP BY kind')
 print('Content counts:',[dict(row) for row in cur.fetchall()])
db.close()
