"""Read PostgreSQL catalogs in Docker and generate database documentation (no row data)."""
import json
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / 'database'
SQL = """
SELECT json_build_object(
 'database',current_database(),
 'captured_at',now(),
 'tables',(SELECT json_agg(x ORDER BY x.schema,x.name) FROM (
   SELECT n.nspname AS schema,c.relname AS name,obj_description(c.oid) AS comment,
    (SELECT json_agg(a ORDER BY a.position) FROM (
      SELECT a.attnum AS position,a.attname AS name,format_type(a.atttypid,a.atttypmod) AS type,
       NOT a.attnotnull AS nullable,pg_get_expr(d.adbin,d.adrelid) AS default_value,
       col_description(c.oid,a.attnum) AS comment
      FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
      WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
    ) a) AS columns,
    (SELECT json_agg(json_build_object('name',k.conname,'type',k.contype,
       'definition',pg_get_constraintdef(k.oid),
       'columns',ARRAY(SELECT attname FROM unnest(k.conkey) WITH ORDINALITY z(num,ord)
          JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum=z.num ORDER BY z.ord),
       'target_schema',tn.nspname,'target_table',tc.relname,
       'target_columns',ARRAY(SELECT attname FROM unnest(k.confkey) WITH ORDINALITY z(num,ord)
          JOIN pg_attribute a ON a.attrelid=k.confrelid AND a.attnum=z.num ORDER BY z.ord)))
     FROM pg_constraint k LEFT JOIN pg_class tc ON tc.oid=k.confrelid
       LEFT JOIN pg_namespace tn ON tn.oid=tc.relnamespace WHERE k.conrelid=c.oid) AS constraints,
    (SELECT json_agg(json_build_object('name',ic.relname,'definition',pg_get_indexdef(i.indexrelid),
       'unique',i.indisunique,'partial',i.indpred IS NOT NULL,
       'columns',ARRAY(SELECT attname FROM unnest(i.indkey::smallint[]) z(num)
          JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum=z.num)))
       FROM pg_index i JOIN pg_class ic ON ic.oid=i.indexrelid WHERE i.indrelid=c.oid) AS indexes
   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE c.relkind IN ('r','p') AND n.nspname NOT IN ('pg_catalog','information_schema')
     AND n.nspname NOT LIKE 'pg_toast%'
 ) x),
 'views',(SELECT json_agg(json_build_object('schema',schemaname,'name',viewname))
   FROM pg_views WHERE schemaname NOT IN ('pg_catalog','information_schema')),
 'migrations',(SELECT json_agg(version ORDER BY version) FROM public.schema_migrations)
);
"""


def cell(value):
    return str(value if value is not None else '—').replace('|', '\\|').replace('\n', '<br>')


def row(values):
    return '| ' + ' | '.join(cell(v) for v in values) + ' |'


def main():
    snapshots = []
    for container, database in [('track-children-postgres', 'track_children'),
                                ('track-children-ai-postgres', 'track_children_ai')]:
        result = subprocess.run(['docker', 'exec', container, 'psql', '-X', '-A', '-t',
                                 '-v', 'ON_ERROR_STOP=1', '-U', 'track_children', '-d', database,
                                 '-c', SQL], capture_output=True, encoding='utf-8')
        if result.returncode:
            raise SystemExit(f'Cannot read {database}: {result.stderr.strip()}')
        snapshots.append(json.loads(result.stdout))
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'database-catalog.json').write_text(json.dumps(snapshots, ensure_ascii=False, indent=2), encoding='utf-8')
    tables = {}
    for snapshot in snapshots:
        for table in snapshot['tables']:
            key = snapshot['database'] + '.' + table['schema'] + '.' + table['name']
            table['database'] = snapshot['database']
            tables[key] = table
    ids = {key: f'T{i:03}' for i, key in enumerate(tables, 1)}
    doc = ['# Danh mục toàn bộ bảng và trường dữ liệu', '',
           'Nguồn: truy vấn chỉ đọc PostgreSQL catalog của hai database Docker đang chạy. Không xuất dữ liệu cá nhân trong các dòng dữ liệu.', '',
           'Thời điểm chụp: ' + ', '.join(s['database'] + ': ' + s['captured_at'] for s in snapshots), '',
           f'Tổng: **{len(tables)} bảng**, **{sum(len(t["columns"]) for t in tables.values())} trường**. Bao gồm bảng kỹ thuật `public.schema_migrations` của mỗi database; view liệt kê riêng.', '',
           '[Ma trận quan hệ](RELATIONSHIP-MATRIX.md) · [Catalog JSON](database-catalog.json)', '',
           '## Tổng hợp bảng', '', row(['Mã', 'Database', 'Schema', 'Bảng', 'Số trường', 'Khóa chính']), row(['---'] * 6)]
    for key, t in tables.items():
        pk = next((k['columns'] for k in t['constraints'] or [] if k['type'] == 'p'), [])
        doc.append(row([ids[key], t['database'], t['schema'], t['name'], len(t['columns']), ', '.join(pk)]))
    for key, t in tables.items():
        constraints = t['constraints'] or []
        doc += ['', f'## {ids[key]} — {key}', '',
                t['comment'] or ('Bảng theo dõi migration đã áp dụng.' if t['name'] == 'schema_migrations' else ''), '',
                row(['STT', 'Trường', 'Kiểu PostgreSQL', 'Cho NULL', 'Khóa', 'Mặc định', 'Tham chiếu', 'Mô tả trong DB']), row(['---'] * 8)]
        for c in t['columns']:
            keys = sorted({{'p': 'PK', 'f': 'FK', 'u': 'UK'}[k['type']] for k in constraints
                           if k['type'] in ('p', 'f', 'u') and c['name'] in k['columns']})
            refs = [k['target_schema'] + '.' + k['target_table'] + '(' + ', '.join(k['target_columns']) + ')'
                    for k in constraints if k['type'] == 'f' and c['name'] in k['columns']]
            doc.append(row([c['position'], c['name'], c['type'], 'Có' if c['nullable'] else 'Không',
                            ', '.join(keys), c['default_value'], '; '.join(refs), c['comment']]))
        doc += ['', '**Ràng buộc** (PK/UK ghép phải đọc theo cả tập cột):', '']
        doc += ['- `' + k['name'] + '`: `' + k['definition'] + '`' for k in constraints]
        doc += ['', '**Index** (gồm unique/partial index không thể hiện hết ở cột Khóa):', '']
        doc += ['- `' + i['definition'] + '`' for i in t['indexes'] or []]
    doc += ['', '## View và migration', '']
    for s in snapshots:
        doc += ['- **' + s['database'] + '** — migration: ' + ', '.join(s['migrations'] or []),
                '  - View: ' + (', '.join(v['schema'] + '.' + v['name'] for v in s['views'] or []) or 'Không có view ứng dụng.')]
    (OUT / 'DATA-DICTIONARY.md').write_text('\n'.join(doc) + '\n', encoding='utf-8')

    edges = []
    for key, t in tables.items():
        for k in t['constraints'] or []:
            if k['type'] != 'f':
                continue
            parent = t['database'] + '.' + k['target_schema'] + '.' + k['target_table']
            assert parent in tables
            cols = set(k['columns'])
            unique = any(i['unique'] and not i['partial'] and set(i['columns'] or []) <= cols
                         and i['columns'] for i in t['indexes'] or [])
            required = all(not c['nullable'] for c in t['columns'] if c['name'] in cols)
            edges.append((key, parent, k, unique, required))
    mat = ['# Ma trận quan hệ giữa các bảng', '',
           'Nguồn: cùng snapshot PostgreSQL catalog với [danh mục trường dữ liệu](DATA-DICTIONARY.md).', '',
           f'Có **{len(tables)} bảng** và **{len(edges)} ràng buộc khóa ngoại vật lý**. Khóa ngoại ghép tính là một quan hệ.', '',
           '## Quy ước', '',
           '- Hàng = bảng con chứa FK; cột = bảng cha được tham chiếu. Số trong ô = số FK độc lập, không phải số dòng dữ liệu. `·` = không có FK trực tiếp. Đường chéo có thể có tự tham chiếu.',
           '- Mã Txxx khớp danh mục bên dưới. Chia ma trận theo database vì PostgreSQL không có FK chéo database.',
           '- Một bảng cha có 0..N bảng ghi con; nếu FK có tính duy nhất toàn cục thì tối đa 1 bản ghi con. Phía cha của mỗi bản ghi con là 1 nếu tất cả cột FK NOT NULL, ngược lại 0..1. Với FK ghép nullable, xem thêm CHECK/MATCH trong định nghĩa SQL.', '',
           '## Danh mục mã bảng', '', row(['Mã', 'Bảng đầy đủ']), row(['---', '---'])]
    mat += [row([ids[k], k]) for k in tables]
    counts = Counter((child, parent) for child, parent, *_ in edges)
    for s in snapshots:
        subset = [k for k, t in tables.items() if t['database'] == s['database']]
        mat += ['', '## Ma trận ' + s['database'], '', row(['Con ↓ / Cha →'] + [ids[k] for k in subset]), row(['---'] * (len(subset) + 1))]
        mat += [row([ids[a]] + [counts.get((a, b), '·') for b in subset]) for a in subset]
    mat += ['', '## Chi tiết khóa ngoại vật lý', '',
            row(['Bảng con', 'Cột FK', 'Bảng cha', 'Cột đích', 'Số cha / một dòng con', 'Số con / một dòng cha', 'Ràng buộc SQL']), row(['---'] * 7)]
    for child, parent, k, unique, required in edges:
        mat.append(row([ids[child], ', '.join(k['columns']), ids[parent], ', '.join(k['target_columns']),
                        '1' if required else '0..1', '0..1' if unique else '0..N', k['definition']]))
    mat += ['', '## Tham chiếu logic của AI (không phải FK)', '',
            'Các ID/mảng sau phản ánh thiết kế trong migration AI; không có bảo đảm toàn vẹn tham chiếu từ PostgreSQL. Chúng không được tính trong ma trận FK ở trên.', '',
            row(['Trường nguồn', 'Đích logic', 'Ghi chú']), row(['---'] * 3)]
    logical = [
        ('ai_kb.kb_documents', 'source_id', 'reference.reference_sources', 'id'),
        ('ai_kb.kb_documents', 'uploaded_by', 'admin.admin_users', 'id'),
        ('ai_kb.candidate_criteria', 'domain_id', 'criteria.developmental_domains', 'id'),
        ('ai_kb.candidate_criteria', 'milestone_id', 'criteria.age_milestones', 'id'),
        ('ai_kb.candidate_criteria', 'reviewed_by', 'admin.admin_users', 'id'),
        ('ai_kb.candidate_criteria', 'promoted_criterion_id', 'criteria.criteria', 'id'),
        ('ai_chatbot.chat_conversations', 'user_id', 'account.users', 'id'),
        ('ai_chatbot.chat_conversations', 'child_id', 'child.children', 'id'),
        ('ai_chatbot.chat_request_logs', 'user_id', 'account.users', 'id'),
        ('ai_chatbot.unanswered_questions', 'handled_by', 'admin.admin_users', 'id'),
        ('ai_analysis.analysis_logs', 'assessment_id', 'assessment.assessments', 'id'),
        ('ai_analysis.analysis_logs', 'child_id', 'child.children', 'id'),
        ('ai_analysis.analysis_logs', 'reference_version_id', 'reference.reference_data_versions', 'id'),
        ('ai_analysis.analysis_logs', 'used_chunk_ids', 'ai_kb.kb_chunks', 'id (mảng)'),
        ('ai_vision.video_analysis_jobs', 'media_id', 'diary.diary_media', 'id; unique media_id'),
        ('ai_vision.video_analysis_jobs', 'entry_id', 'diary.diary_entries', 'id'),
        ('ai_vision.video_analysis_jobs', 'child_id', 'child.children', 'id'),
        ('ai_vision.video_analysis_jobs', 'activity_id', 'activity.activities', 'id'),
        ('ai_vision.parent_feedback', 'user_id', 'account.users', 'id'),
        ('ai_vision.expert_labels', 'labeler_id', 'admin.admin_users', 'id'),
        ('ai_vision.model_registry', 'created_by', 'admin.admin_users', 'id'),
        ('ai_vision.model_registry', 'activity_ids', 'activity.activities', 'id (mảng)'),
        ('ai_vision.ai_evaluations', 'model_version', 'ai_vision.model_registry', 'version (chuỗi)')]
    for source, column, target, note in logical:
        sk = 'track_children_ai.' + source
        tk = ('track_children_ai.' if target.startswith('ai_') else 'track_children.') + target
        assert sk in tables and tk in tables
        assert column in {c['name'] for c in tables[sk]['columns']}
        mat.append(row([sk + '.' + column, tk, note]))
    (OUT / 'RELATIONSHIP-MATRIX.md').write_text('\n'.join(mat) + '\n', encoding='utf-8')
    print(json.dumps({'tables': len(tables), 'fields': sum(len(t['columns']) for t in tables.values()),
                      'foreign_keys': len(edges), 'logical_references': len(logical),
                      'databases': {s['database']: len(s['tables']) for s in snapshots}}, ensure_ascii=False))


if __name__ == '__main__':
    main()
