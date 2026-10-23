# Backend

FastAPI service for the Track Children API.

```powershell
pip install -r requirements.txt
copy .env.example .env          # DATABASE_URL, DEV_AUTH=true khi phát triển
uvicorn app.main:app --reload
```

Health check: `GET /health`. API docs: http://localhost:8000/docs — hợp đồng API
xem `docs/api/README.md`.

## Database migrations

Start the local PostgreSQL containers from the repository root, then run:

```powershell
.\scripts\migrate.ps1 -Target backend
```

Migrations are stored in `backend/migrations/` and are applied in filename
order. The `public.schema_migrations` table records each applied migration.

## Dữ liệu demo cho mobile

Chưa có đăng nhập thật. Để mobile đồng bộ sổ tiêm, seed tài khoản + hồ sơ trẻ
có uuid cố định khớp `mobile/lib/services/api_config.dart`:

```powershell
python -m app.seed.demo
```

Mobile gọi `http://10.0.2.2:8000` trên Android emulator, `http://localhost:8000`
ở nơi khác; thiết bị thật: `flutter run --dart-define=API_BASE_URL=http://<IP LAN>:8000`
(và chạy uvicorn với `--host 0.0.0.0`).

## Tests

`pytest` — `tests/test_vaccination.py` cần PostgreSQL local đã migrate (không có thì bỏ qua).

Sau khi đổi seed lịch tiêm, xuất lại bản dự phòng offline cho mobile:
`python -m app.seed.export_mobile_schedule`.
