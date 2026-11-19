"""Build a pinned offline password denylist; no user passwords are transmitted."""
import hashlib
import json
from pathlib import Path
import re
import sys
import httpx

def build(commit):
    if not re.fullmatch('[0-9a-f]{40}',commit):raise ValueError('Full upstream commit required')
    base=f'https://raw.githubusercontent.com/danielmiessler/SecLists/{commit}/'
    source='Passwords/Common-Credentials/xato-net-10-million-passwords-100000.txt'
    with httpx.Client(timeout=30,follow_redirects=False) as client:
        data=client.get(base+source);data.raise_for_status()
        license=client.get(base+'LICENSE');license.raise_for_status()
    if 'MIT License' not in license.text:raise ValueError('Review upstream license before update')
    words={line.casefold() for line in data.text.splitlines() if 8<=len(line)<=64 and all(33<=ord(c)<=126 for c in line)}
    for baseword in ('belonkhon','matkhau','phuhuynh','conyeu','yeucon','chamsocbe'):
        words.update(baseword+suffix for suffix in ('123','1234','123456','2026','2027','123!','@123','!123','1!','12345'))
    if len(words)<10000:raise ValueError('Unexpected upstream dataset')
    output=Path(__file__).resolve().parents[1]/'data'/'auth';output.mkdir(parents=True,exist_ok=True)
    raw=('\n'.join(sorted(words))+'\n').encode('utf-8')
    (output/'common-passwords.txt').write_bytes(raw)
    (output/'SecLists-LICENSE.txt').write_bytes(license.content)
    (output/'blocklist-manifest.json').write_text(json.dumps({'source':base+source,'commit':commit,
        'upstreamSha256':hashlib.sha256(data.content).hexdigest(),'sha256':hashlib.sha256(raw).hexdigest(),
        'entries':len(words),'license':'MIT','transformation':'ASCII 8-64, casefold, unique; app-specific additions'},indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'entries':len(words),'sha256':hashlib.sha256(raw).hexdigest()}))

if __name__=='__main__':build(sys.argv[1])
