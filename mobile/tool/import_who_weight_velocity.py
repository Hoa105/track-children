"""Read WHO 1-month weight increment display bounds without deriving Z-scores."""
import hashlib
import json
from import_who_weight_curves import DATA, read_rows

def main():
    output = {'unit': 'g', 'interval_months': 1, 'tables': {}, 'sources': {}}
    for sex, version in [('boys', '96b0a570_7'), ('girls', 'd2c6d0df_5')]:
        name = f'ttt-weight-{sex}-1mon-z.xlsx'
        path = DATA / 'sources' / name
        raw = read_rows(path)
        headers = {str(v).lower(): k for k, v in raw[0].items()}
        columns = [headers[n] for n in ['interval', '-2 sd', 'median', '2 sd']]
        rows = [[i, *[r[c] for c in columns]] for i, r in enumerate(raw[1:])]
        assert len(rows) == 12
        assert all(r[2] < r[3] < r[4] for r in rows)
        output['tables'][sex] = rows
        output['sources'][sex] = {'url': 'https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/weight-velocity/'+name+'?sfvrsn='+version,
                                  'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    (DATA / 'weight_velocity_1month.json').write_text(json.dumps(output, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Validated 12 WHO intervals per sex; -2 SD, median, +2 SD copied verbatim.')

if __name__ == '__main__':
    main()
