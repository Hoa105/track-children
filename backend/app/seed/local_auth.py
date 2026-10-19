"""Explicit local sample-data migration. Never run automatically in production."""
from pathlib import Path

from app.core.config import settings
from app.core.database import transaction
from app.core.security import password_hasher

SAMPLE_PASSWORD = 'Ab12!x'


def seed(db):
    if settings.app_env != 'local':
        raise RuntimeError('Sample auth migration requires APP_ENV=local')
    path = Path(__file__).resolve().parents[2] / 'migrations/local/008_auth_samples.sql'
    with db.transaction():
        db.execute("SELECT set_config('app.sample_password_hash', %s, true)",
                   (password_hasher.hash(SAMPLE_PASSWORD),))
        db.execute(path.read_text(encoding='utf-8'))


def main():
    with transaction() as db:
        seed(db)
    print('Local samples ready: parent01@example.com through parent10@example.com; password: Ab12!x')


if __name__ == '__main__':
    main()
