"""Tài khoản + hồ sơ trẻ demo, khớp DemoStore của mobile (mobile/lib/services/api_config.dart).

Chỉ dùng khi phát triển (DEV_AUTH=true), để mobile đồng bộ sổ tiêm lên backend
trước khi có đăng nhập thật. Chạy lại an toàn:

    python -m app.seed.demo
"""

import datetime as dt

import psycopg2

from app.core.config import settings

# Mật khẩu demo của mobile (TreXanh123) — hash bcrypt chỉ để thỏa NOT NULL, chưa dùng để đăng nhập
_PASSWORD_HASH = "$2b$12$demo.only.not.a.real.hash.for.login.xxxxxxxxxxxxxxxxxx"

PARENTS = [
    ("00000000-0000-4000-8000-000000000001", "demo@trackchildren.vn", "Nguyễn Thị Hoa", "hoa_nguyen", "mẹ"),
    ("00000000-0000-4000-8000-000000000002", "bo@trackchildren.vn", "Trần Minh Đức", "duc_tran", "bố"),
]

# (id, chủ, tên, giới tính, số tháng tuổi) — DemoStore._fixture
CHILDREN = [
    ("00000000-0000-4000-8000-000000000101", PARENTS[0][0], "Bảo An", "male", 8),
    ("00000000-0000-4000-8000-000000000102", PARENTS[0][0], "Gia Linh", "female", 30),
    ("00000000-0000-4000-8000-000000000103", PARENTS[1][0], "Minh Khang", "male", 14),
]


def _months_ago(today: dt.date, months: int) -> dt.date:
    year, month = divmod(today.year * 12 + today.month - 1 - months, 12)
    month += 1
    last_day = (dt.date(year + month // 12, month % 12 + 1, 1) - dt.timedelta(days=1)).day
    return dt.date(year, month, min(today.day, last_day))


def seed(today: dt.date | None = None) -> None:
    today = today or dt.date.today()
    with psycopg2.connect(settings.database_url) as conn, conn.cursor() as cur:
        for user_id, email, name, username, relationship in PARENTS:
            cur.execute(
                """
                INSERT INTO account.users
                  (id, email, password_hash, full_name, username, relationship, status, email_verified_at)
                VALUES (%s, %s, %s, %s, %s, %s, 'active', now())
                ON CONFLICT (id) DO NOTHING
                """,
                (user_id, email, _PASSWORD_HASH, name, username, relationship),
            )
        for child_id, owner, name, gender, months in CHILDREN:
            cur.execute(
                """
                INSERT INTO child.children
                  (id, owner_user_id, full_name, date_of_birth, gender, gestational_weeks, birth_weight_kg)
                VALUES (%s, %s, %s, %s, %s, 40, 3.2)
                ON CONFLICT (id) DO NOTHING
                """,
                (child_id, owner, name, _months_ago(today, months), gender),
            )
    print(f"Seeded {len(PARENTS)} parents and {len(CHILDREN)} children.")


if __name__ == "__main__":
    seed()
