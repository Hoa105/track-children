"""Small real-DB auth harness; independent of growth/R, AI and media providers."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.features.auth.simulation import require
require()
from app.features.auth.setup import install_auth
from app.features.children.router import router as children_router

app=FastAPI(title='Bé Lớn Khôn — Auth local simulation')
app.add_middleware(CORSMiddleware,allow_origin_regex=r'http://(localhost|127\.0\.0\.1)(:[0-9]+)?',
                   allow_methods=['*'],allow_headers=['*'])
install_auth(app)
app.include_router(children_router)

@app.get('/health')
def health():return {'status':'ok','authSimulation':True}
