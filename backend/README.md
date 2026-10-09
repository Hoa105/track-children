# Backend

FastAPI service for the Track Children API.

```powershell
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Health check: `GET /health`.

## Database migrations

Start the local PostgreSQL containers from the repository root, then run:

```powershell
.\scripts\migrate.ps1 -Target backend
```

Migrations are stored in `backend/migrations/` and are applied in filename
order. The `public.schema_migrations` table records each applied migration.
