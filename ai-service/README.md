# AI Service

Service for rule-based NLP, indicator mapping, rule evaluation, and optional
LLM integrations.

```powershell
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```

## Database migrations

Start the local PostgreSQL containers from the repository root, then run:

```powershell
.\scripts\migrate.ps1 -Target ai
```

Migrations are stored in `ai-service/migrations/` and are applied in filename
order. The `public.schema_migrations` table records each applied migration.
