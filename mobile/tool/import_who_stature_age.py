"""Extract WHO length/height-for-age display curves, keeping methods separate."""
import hashlib
import json
from import_who_weight_curves import DATA, ROOT, read_rows

def main():
    old = json.loads((ROOT/'assets/data/who_growth.json').read_text(encoding='utf-8'))
    output = {'indicator': 'length-height-for-age', 'unit': 'cm', 'tables': {}, 'sources': {}}
    for sex in ['boys', 'girls']:
        for length in [True, False]:
            key = f"{'length' if length else 'height'}_{sex}"
            url = 'https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/'+old['sources']['height'][sex][0 if length else 1]
            path = DATA/'sources'/url.split('/')[-1].split('?')[0]
            raw = read_rows(path)
            headers = {str(v).strip().lower(): c for c,v in raw[0].items()}
            cols = [headers[n] for n in ['month','sd3neg','sd2neg','sd0','sd2','sd3']]
            rows = [[r[c] for c in cols] for r in raw[1:]]
            assert [r[0] for r in rows] == list(range(0,25) if length else range(24,61))
            assert all(all(a<b for a,b in zip(r[1:],r[2:])) for r in rows)
            assert [[r[0],r[2],r[3],r[4]] for r in rows] == (old['height'][sex][:25] if length else old['height'][sex][25:])
            output['tables'][key] = rows
            output['sources'][key] = {'url': url, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    (DATA/'stature_for_age_curves.json').write_text(json.dumps(output,indent=2)+'\n',encoding='utf-8')
    print('Validated four WHO tables and all existing inner thresholds; 24-month methods remain separate.')

if __name__ == '__main__':
    main()
