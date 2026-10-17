# Backend

FastAPI service for the Track Children API.

```powershell
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Health check: `GET /health`.

## Growth tracking

See [setup and API usage](../docs/api/mobile-growth.md),
[OpenAPI contract](../docs/api/mobile-growth.openapi.json),
[test plan](../docs/api/mobile-growth-test-plan.md) and
[test results](../docs/api/mobile-growth-test-results.md).

Set `DATABASE_URL` and a random `AUTH_SECRET` of at least 32 characters before
using protected routes. For local startup from `backend/`, copy `.env.example`
to `.env`, configure it, then run `uvicorn app.main:app --env-file .env --reload`.
Docker Compose reads `AUTH_SECRET`/`CORS_ORIGINS` from the shell or root `.env`.

## Database migrations

Start the local PostgreSQL containers from the repository root, then run:

```powershell
.\scripts\migrate.ps1 -Target backend
```

Migrations are stored in `backend/migrations/` and are applied in filename
order. The `public.schema_migrations` table records each applied migration.
