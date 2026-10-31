"""Extract the checked-in WHO length velocity workbooks without dependencies."""
import hashlib
import json
import re
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
result = {'unit': 'cm', 'source': 'WHO Growth velocity 2009, chapter 4', 'tables': {}}
for sex in ('boys', 'girls'):
    result['tables'][sex] = {}
    for period in (2, 3, 4, 6):
        path = next((ROOT / 'docs/core_growth/Length-velocity' / sex).glob(f'*_{period}mon_z.xlsx'))
        with ZipFile(path) as archive:
            strings = [''.join(t.itertext()) for t in ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('m:si', NS)]
            rows = []
            for row in ET.fromstring(archive.read('xl/worksheets/sheet1.xml')).findall('m:sheetData/m:row', NS)[1:]:
                cells = []
                for cell in row:
                    value = cell.find('m:v', NS)
                    if value is not None:
                        cells.append(strings[int(value.text)] if cell.get('t') == 's' else float(value.text))
                if not cells:
                    continue
                match = re.fullmatch(r'(\d+)-(\d+) mo', cells[0])
                assert match, cells
                start, end = map(int, match.groups())
                assert end - start == period
                rows.append({'start': start, 'end': end, 'l': cells[1], 'm': cells[2], 's': cells[3], 'sd': cells[4:11]})
        assert len(rows) == 25 - period
        result['tables'][sex][str(period)] = {'file': str(path.relative_to(ROOT)).replace('\\', '/'), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'rows': rows}
target = ROOT / 'mobile/assets/data/who/stature_velocity_periods.json'
target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Wrote {target.name}: 8 tables')
