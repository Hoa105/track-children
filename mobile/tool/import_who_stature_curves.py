"""Extract five display curves verbatim from the four original WHO XLSX tables."""
import hashlib
import json
from import_who_weight_curves import DATA, read_rows

BASE = 'https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/weight-for-length-height/'
VERSIONS = {'length_girls': '288bc4e4_7', 'height_girls': '4d66af6a_7',
            'length_boys': 'e27a9da3_7', 'height_boys': '202c0545_7'}

def main():
    output = {'unit': 'kg', 'x_unit': 'cm', 'tables': {}, 'sources': {}}
    for key, version in VERSIONS.items():
        kind, sex = key.split('_')
        name = f"{'wfl' if kind == 'length' else 'wfh'}_{sex}_{'0-to-2' if kind == 'length' else '2-to-5'}-years_zscores.xlsx"
        path = DATA / 'sources' / name
        raw = read_rows(path)
        headers = {str(v).lower(): col for col, v in raw[0].items()}
        cols = [headers[n] for n in [kind, 'sd3neg', 'sd2neg', 'sd0', 'sd2', 'sd3']]
        rows = [[r[c] for c in cols] for r in raw[1:]]
        low, high = (45, 110) if kind == 'length' else (65, 120)
        assert len(rows) == int((high-low)*2)+1
        for i, row in enumerate(rows):
            assert row[0] == low + i*.5
            assert all(0 < a < b for a, b in zip(row[1:], row[2:]))
        output['tables'][key] = rows
        output['sources'][key] = {'url': BASE+name+'?sfvrsn='+version,
                                 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        print(key, len(rows), 'validated rows', rows[0], rows[-1])
    (DATA / 'weight_for_stature_curves.json').write_text(json.dumps(output, indent=2)+'\n', encoding='utf-8')

if __name__ == '__main__':
    main()
