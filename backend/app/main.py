from fastapi import FastAPI

app = FastAPI(title="Track Children API", version="0.1.0")


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
