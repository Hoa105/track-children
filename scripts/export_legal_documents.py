"""Rebuild local-only policy JSON from versioned Vietnamese source documents."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
files={'terms':'terms.vi.md','privacy':'privacy.vi.md','data_policy':'data-policy.vi.md'}
docs=[{'docType':kind,'version':'trial-1.0','content':(root/'docs/legal'/name).read_text(encoding='utf-8').strip(),
       'isRequired':True,'effectiveAt':'2026-11-19T00:00:00+07:00'} for kind,name in files.items()]
(root/'backend/legal-documents.local.json').write_text(json.dumps(docs,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Exported local policy documents; no DB changes.')
