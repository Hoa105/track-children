"""Extract original WHO 2-month head circumference increment display thresholds, in cm."""
import hashlib
import json
from pathlib import Path
from import_who_weight_curves import read_rows

DATA = Path(__file__).resolve().parents[1] / 'assets/data/who'
result = {'interval_months': 2, 'unit': 'cm', 'columns': ['start_month', 'sd_neg2', 'median', 'sd_pos2'], 'tables': {}, 'sources': {}}
for sex, version in [('boys', 'c84c1459_7'), ('girls', '5721a52d_7')]:
    name = f'ttt_headc_{sex}_2mon_z.xlsx'
    path = DATA / 'sources' / name
    rows = read_rows(path)[1:]
    assert len(rows) == 11
    table = []
    for start, row in enumerate(rows):
        assert row['A'] == f'{start}-{start+2} mo'
        assert row['F'] < row['H'] < row['J']
        table.append([start, row['F'], row['H'], row['J']])
    result['tables'][sex] = table
    result['sources'][sex] = {
        'url': f'https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/head-circumference-velocity/{name}?sfvrsn={version}',
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
    }
(DATA / 'head_velocity_2month.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
