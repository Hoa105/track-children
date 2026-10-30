"""Loopback-only HTTP fixture for Flutter growth integration, dedicated test DB only."""

import os
from uuid import UUID, uuid4
import psycopg
import uvicorn
from app.core.config import settings
from app.main import app
from app.features.auth.dependencies import current_user_id

url = os.environ["GROWTH_TEST_DATABASE_URL"]
assert psycopg.conninfo.conninfo_to_dict(url)["dbname"].endswith("_growth_test")
settings.database_url = url
owner = uuid4()
child = UUID("00000000-0000-4000-8000-000000009901")
with psycopg.connect(url) as db:
    db.execute(
        "INSERT INTO account.users(id,display_name,email,password_hash,status) VALUES (%s,'HTTP Growth Fixture',%s,'test','active')",
        (owner, str(owner) + "@example.test"),
    )
    db.execute(
        "INSERT INTO child.children(id,owner_user_id,full_name,date_of_birth,gender) VALUES (%s,%s,'HTTP Growth Fixture','2025-01-01','female') ON CONFLICT(id) DO UPDATE SET owner_user_id=excluded.owner_user_id",
        (child, owner),
    )
    db.execute("DELETE FROM growth.measurements WHERE child_id=%s", (child,))
# Authentication bypass exists only in this test runner, never the production app.
app.dependency_overrides[current_user_id] = lambda: owner
if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8009, log_level="warning")
