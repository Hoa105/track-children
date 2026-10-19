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

## Mobile authentication

Contract: [Mobile Auth](../docs/api/mobile-auth.md),
[OpenAPI JSON](../docs/api/mobile-auth.openapi.json).

Run all backend migrations including `007_mobile_auth.sql` before using auth.
From `backend/`, copy `.env.example` to `.env` and configure:

- `AUTH_SECRET`: a random secret of at least 32 characters, shared by all workers.
  Generate locally with `python -c "import secrets; print(secrets.token_urlsafe(48))"`.
- `DATABASE_URL`: the application PostgreSQL database.
- `SMS_WEBHOOK_URL`: HTTPS SMS adapter endpoint, accepting JSON `{to, message}`.
- `SMS_WEBHOOK_TOKEN`: Bearer credential for that endpoint. Any 2xx means accepted;
  timeout/non-2xx means delivery failed. No debug/default OTP is exposed.
- `CORS_ORIGINS`: optional JSON array of exact origins for Flutter web.

The SMS webhook is an integration boundary: provide an adapter for your selected
SMS vendor. Credentials and actual SMS delivery have not been validated here.
For Docker Compose, set these variables in the shell or root `.env`; do not commit
secrets. Configure uvicorn's trusted proxy IPs to match your deployment.

Import approved legal documents before registration can work:

```powershell
python -m app.seed.legal_documents path/to/reviewed-documents.json
```

Input is a JSON array containing `terms`, `privacy`, `data_policy`, each with
`docType`, `version`, `content`, `isRequired`, and timezone-aware `effectiveAt`.
Existing versions are immutable through this importer; publish a new version for
new content. No placeholder legal terms are silently accepted in production.

Protected mobile routes can use `Depends(app.shared.access.require_user)`.
The dependency checks both JWT claims and the current PostgreSQL session/user.

## Auth tests

### Local testing without SMS/OTP

Set `APP_ENV=local` and `AUTH_SKIP_OTP=true` in `backend/.env`, then restart
the Python backend. Registration returns `requiresOtp: false`; the mobile app
logs in immediately without opening the OTP dialog. Pending accounts can also
log in with their correct password. Phone verification timestamps remain null.
OTP remains enabled by default; bypass configuration is rejected outside local.
Set `AUTH_SKIP_OTP=false` and restart to restore OTP for new/pending accounts.
Accounts already activated locally remain active.

Optional sample migration (Git Bash, from repository root):

```bash
cd backend
PYTHONPATH="../.test-deps;." python -m app.seed.local_auth
```

This applies `migrations/local/008_auth_samples.sql`, creating ten active local
accounts `parent01@example.com` through `parent10@example.com`, password `Ab12!x`.
Existing conflicting accounts are preserved. These are auth accounts only;
they do not contain child profiles. Local seed data is excluded from normal
schema migrations and requires `APP_ENV=local`.

Docker Compose (Git Bash, repository root):

```bash
export APP_ENV=local AUTH_SKIP_OTP=true
export AUTH_SECRET="$(sed -n 's/^AUTH_SECRET=//p' backend/.env)"
docker compose up -d --build backend
docker compose exec backend python -m app.seed.local_auth
```

The local legal documents can be imported separately as documented above.

```powershell
python -m pip install -r backend/requirements-dev.txt
.\scripts\test-auth.ps1
```

Run these commands from the repository root. The script uses a dedicated Docker
container `track-children-auth-test`, localhost port 55439, database
`track_children_auth_test`. Test fixtures reset data only in a database whose name
ends in `_test`. Existing application containers/data are not used. The container
is left running for subsequent test runs; stop it with `docker stop track-children-auth-test`.

Alternatively set `AUTH_TEST_DATABASE_URL`, add `backend` to `PYTHONPATH`, then run
`python -m pytest backend/tests -q`. Without that variable, PostgreSQL integration
tests are skipped, not reported as passing. Tests use an SMS fake and controlled clock.

Mobile: `cd mobile`, `flutter pub get`, `flutter test`. For Android emulator local
API: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`.
For physical devices/iOS use a reachable HTTPS URL. Cleartext is enabled only in
the Android debug manifest. Refresh secrets use platform secure storage; local
feature data remains local, not synchronized to a child-profile backend yet.

Logout clears credentials and active selections. Locally authored child data is
retained under its owner ID rather than destroyed before server synchronization
exists; another authenticated account cannot select/read that owner's profiles.
Android backups are disabled to avoid restoring encrypted auth preferences without
the device key. Schedule `python -m app.features.auth.maintenance` periodically to
remove expired sessions, challenges, codes and throttle windows.

For the live Flutter HTTP smoke, first run (root, after backend integration tests):

```powershell
$env:PYTHONPATH = "$PWD/backend"
$env:AUTH_TEST_DATABASE_URL = 'postgresql://auth_test:auth_test_local@127.0.0.1:55439/track_children_auth_test'
python -m tests.auth.live_server
```

In a second terminal from `mobile/`:

```powershell
flutter test test/auth_live_test.dart --dart-define=AUTH_LIVE_TEST=true --dart-define=API_BASE_URL=http://127.0.0.1:8009/api/v1
```

This localhost-only harness uses the test DB and a private, ignored SMS fixture
file. It is not shipped with the application. Do not run DB-resetting tests at the
same time as the live smoke. By default, the live test is explicitly skipped.
