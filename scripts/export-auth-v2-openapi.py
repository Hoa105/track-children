"""Export request schemas/routes; no DB connection or environment mutation."""
import yaml
import sys
from pathlib import Path

root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'backend'))
from fastapi import FastAPI
from app.features.auth.router_v2 import router

app=FastAPI(title='Track Children - Mobile Auth v2 API',version='2.1.0')
app.include_router(router)
document=app.openapi()
document['info']['description']='Request schemas generated from implementation. Response contracts, compatibility and deployment gates: docs/api/mobile-auth-v2.md.'
(root/'docs/api/mobile-auth-v2.openapi.yaml').write_text(
    yaml.safe_dump(document,allow_unicode=True,sort_keys=False),encoding='utf-8')
print('Exported auth v2 OpenAPI request schemas and routes.')
