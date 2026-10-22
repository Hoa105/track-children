# Auth module

The API contract and database schema are unchanged by this refactor.

- `router.py`: request validation, transaction boundaries, HTTP endpoints.
- `schemas.py`: Pydantic request models and input rules.
- `service.py`: registration, OTP, login, refresh, logout and throttling rules.
- `repository.py`: parameterized SQL; never commits on behalf of a caller.
- `dependencies.py`: Bearer identity/session checks and protected-route dependency.
- `errors.py`: transport-independent failure values.
- `presenters.py`: HTTP status, headers, JSON serialization and SMS delivery status.
- `sms.py`: external SMS webhook adapter.
- `setup.py`: auth route registration and exception handlers.
- `maintenance.py`: scheduled expiration cleanup entry point.

Dependencies flow from router to service to repository. Service does not import
FastAPI, send SMS or serialize HTTP responses. SMS delivery happens after the
database transaction commits. Expected failures are returned as values so failed
attempt counters and refresh revocations are committed; unexpected exceptions
still roll back. Preserve lock ordering: user before challenge, code or session.

`shared/access.py` re-exports the auth dependency for compatibility and retains
the existing child-access policy. Protected mobile APIs use `require_user` / `current_user_id` with Bearer JWT
and live account sessions. Admin APIs require an admin-audience JWT backed by
`admin.admin_sessions` and assigned database permissions. `X-User-Id` and
`X-Admin-Role` are ignored. Admin token issuance/login is not implemented yet;
mobile tokens cannot authorize admin requests. The `/dev/profiles` helper is
local-only and requires a mobile JWT matching the parent ID.
The psycopg2 pool remains available for existing features. Auth retains its
psycopg 3 transaction context.

Run auth regression tests against a dedicated `*_test` database:

```bash
PYTHONPATH=".test-deps;backend" \
AUTH_TEST_DATABASE_URL=postgresql://auth_test:auth_test_local@127.0.0.1:55439/track_children_auth_test \
python -m pytest backend/tests/auth backend/tests/test_auth_contract.py -q
```
