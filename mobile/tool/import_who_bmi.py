"""Import official WHO numeric BMI tables into an offline Flutter asset."""
import io
import json
import subprocess
from pathlib import Path
import openpyxl

BASE = 'https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/body-mass-index-for-age/'
FILES = {
    'girls': ['bmi_girls_0-to-2-years_zscores.xlsx', 'bmi_girls_2-to-5-years_zscores.xlsx'],
    'boys': ['bmi_boys_0-to-2-years_zcores.xlsx', 'bmi_boys_2-to-5-years_zscores.xlsx'],
}
result = {'source': 'https://www.who.int/toolkits/child-growth-standards/standards/body-mass-index-for-age-bmi-for-age', 'files': FILES}
VERSIONS = ['2be9859c_7', '452aca36_7', 'df725cc9_7', '73010c9b_5']
version_index = 0
for sex, files in FILES.items():
    rows = []
    for filename in files:
        url = BASE + filename + '?sfvrsn=' + VERSIONS[version_index]
        version_index += 1
        payload = subprocess.check_output(['curl.exe', '--fail', '-sSL', '-A', 'Mozilla/5.0', url])
        workbook = openpyxl.load_workbook(io.BytesIO(payload), data_only=True)
        sheet = workbook.active
        values = list(sheet.values)
        print(filename, values[:2])
        for row in values[1:]:
            if isinstance(row[0], (int, float)):
                rows.append(list(row))
    result[sex] = rows
out = Path(__file__).resolve().parents[1] / 'assets/data/who_bmi.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(result, ensure_ascii=False), encoding='utf-8')
print('Saved', out)
