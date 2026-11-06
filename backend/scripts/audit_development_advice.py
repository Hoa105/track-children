import argparse,json,sys
from pathlib import Path
from urllib.parse import urlparse
import psycopg2
from psycopg2.extras import RealDictCursor
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from app.features.development import service
from app.features.development.advice_audit import audit_advice_cases

if __name__=='__main__':
    parser=argparse.ArgumentParser(description='Read-only exhaustive audit of local advice results')
    parser.add_argument('--output')
    args=parser.parse_args()
    db=psycopg2.connect('postgresql://track_children:track_children_dev@localhost:5433/track_children',cursor_factory=RealDictCursor)
    try:
        sets=[{'id':str(row['id']),'age_months':row['age_months'],'question_ids':[item['stable_code'] for item in service.list_content(db,row['id']) if not item['deleted_at']]} for row in service.list_question_sets(db) if not row['deleted_at']]
        advice=[row['payload'] for row in service.list_content(db,kind='advice') if not row['deleted_at']]
        report=audit_advice_cases(sets,advice)
        if args.output: Path(args.output).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report,ensure_ascii=True))
    finally: db.close()
