"""Download WHO monthly growth reference numeric tables for offline charts."""
import io
import json
import subprocess
from pathlib import Path
import openpyxl

BASE = 'https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/'
FILES = {
 'weight': {
  'girls': ['weight-for-age/wfa_girls_0-to-5-years_zscores.xlsx?sfvrsn=4c03b8db_7'],
  'boys': ['weight-for-age/wfa_boys_0-to-5-years_zscores.xlsx?sfvrsn=97a05331_9']},
 'height': {
  'girls': ['length-height-for-age/lhfa_girls_0-to-2-years_zscores.xlsx?sfvrsn=e9e66a95_11','length-height-for-age/lhfa_girls_2-to-5-years_zscores.xlsx?sfvrsn=2ec187b9_11'],
  'boys': ['length-height-for-age/lhfa_boys_0-to-2-years_zscores.xlsx?sfvrsn=30e044c_9','length-height-for-age/lhfa_boys_2-to-5-years_zscores.xlsx?sfvrsn=17e5ad91_9']},
 'head': {
  'girls': ['head-circumference-for-age/hcfa-girls-0-5-zscores.xlsx?sfvrsn=8f959f88_6'],
  'boys': ['head-circumference-for-age/hcfa-boys-0-5-zscores.xlsx?sfvrsn=adf57aa4_8']},
}
result = {'sources': FILES}
for metric, sexes in FILES.items():
 result[metric] = {}
 for sex, paths in sexes.items():
  rows = []
  for path in paths:
   payload = subprocess.check_output(['curl.exe','--fail','-sSL','--max-time','60','-A','Mozilla/5.0',BASE+path])
   sheet = openpyxl.load_workbook(io.BytesIO(payload),data_only=True).active
   values = list(sheet.values)
   print(path, values[:2], flush=True)
   headers = [str(v).lower() for v in values[0]]
   month = headers.index('month')
   indexes = [headers.index(v) for v in ['sd2neg','sd0','sd2']]
   for row in values[1:]:
    if isinstance(row[month], (int,float)):
     rows.append([row[month], *[row[i] for i in indexes]])
  result[metric][sex] = rows
root = Path(__file__).resolve().parents[1]
bmi = json.loads((root/'assets/data/who_bmi.json').read_text(encoding='utf-8'))
result['bmi'] = {sex: [[r[0],r[5],r[7],r[9]] for r in bmi[sex]] for sex in ['boys','girls']}
(root/'assets/data/who_growth.json').write_text(json.dumps(result),encoding='utf-8')
