"""Explicit local sample-data migration. Never run automatically in production."""
from app.core.config import settings
from app.core.database import transaction
from app.core.security import password_hasher

SAMPLE_PASSWORD = 'PhuHuynh@2026'


def seed(db):
    if settings.app_env != 'local':
        raise RuntimeError('Sample auth migration requires APP_ENV=local')
    with db.transaction():
        db.execute("SELECT account.seed_local_auth_samples(%s)",
                   (password_hasher.hash(SAMPLE_PASSWORD),))


def main():
    with transaction() as db:
        seed(db)
    print(f'Local samples ready: 10 fictional caregivers (ngoc.anh@example.com, minh.duc@example.com, ...); password: {SAMPLE_PASSWORD}')


if __name__ == '__main__':
    main()
