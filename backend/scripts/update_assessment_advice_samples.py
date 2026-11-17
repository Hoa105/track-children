"""Update only the six existing local advice templates as new drafts. Never publish."""
import argparse
import sys
from pathlib import Path
from urllib.parse import urlparse
import psycopg2
from psycopg2.extras import RealDictCursor
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from app.features.assessment.admin import service,transfer
from app.features.assessment.admin.advice_samples import enrich_advice_row


def update_samples(db,apply=False):
    if apply:
        with db.cursor() as cur: cur.execute('LOCK TABLE assessment.question_sets,assessment.content_items IN EXCLUSIVE MODE')
    existing=service.list_content(db,kind='advice')
    if {row['stable_code'] for row in existing}!=set(service.VARIANTS):
        raise ValueError('Expected the six existing advice variants; no changes made')
    rows=[enrich_advice_row({'kind':'advice','stable_code':row['stable_code'],'payload':row['payload'],'source_refs':row['source_refs']}) for row in existing if not row['deleted_at']]
    preview=transfer.preview(db,rows)
    if preview['errors']: raise ValueError(preview['errors'])
    if not apply: return {'preview':{action:sum(change['action']==action for change in preview['changes']) for action in ('revision','unchanged')},'skipped_deleted':len(existing)-len(rows)}
    return {**transfer.commit(db,None,preview['rows'],preview['fingerprint']),'skipped_deleted':len(existing)-len(rows)}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply',action='store_true')
    parser.add_argument('--database-url',default='postgresql://track_children:track_children_dev@localhost:5433/track_children')
    args=parser.parse_args()
    if urlparse(args.database_url).hostname not in ('localhost','127.0.0.1'):
        parser.error('This helper only updates a local database')
    db=psycopg2.connect(args.database_url,cursor_factory=RealDictCursor)
    try: print(update_samples(db,args.apply))
    finally: db.close()
