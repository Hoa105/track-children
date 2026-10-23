# Backend

FastAPI service for the Track Children API.

```powershell
pip install -r requirements.txt
copy .env.example .env          # DATABASE_URL, DEV_AUTH=true khi phát triển
uvicorn app.main:app --reload
```

Health check: `GET /health`. API docs: http://localhost:8000/docs — hợp đồng API
xem `docs/api/README.md`.

Đăng ký theo schema 009 và cấu hình OTP local/email/SMS:
[mobile-registration.md](../docs/api/mobile-registration.md).

Đăng ký/đăng nhập Google và Apple, migration bổ sung và cấu hình SDK:
[mobile-social-auth.md](../docs/api/mobile-social-auth.md).

Đăng nhập mật khẩu không dùng bảng `account.auth_rate_limits` đã bỏ ở migration 009.
Bộ đếm giới hạn đăng nhập dùng file SQLite mặc định
`backend/.runtime/auth-rate-limits.sqlite3` (tự tạo, được git-ignore).
`AUTH_RATE_LIMIT_PATH` cho phép đổi đường dẫn; thư mục phải ghi được và tất cả worker
trên cùng máy phải dùng chung file. File này không lưu mật khẩu hay token phiên.
Khi chạy nhiều máy/container API độc lập, cần limiter phân tán dùng chung;
không coi các file SQLite riêng là giới hạn toàn hệ thống.
Cache lỗi thì API trả `503 RATE_LIMIT_UNAVAILABLE`, không bỏ qua giới hạn.

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

`/dev/profiles` ch? b?t khi `APP_ENV=local` v? `DEV_AUTH=true`, y?u c?u JWT
c?a ch?nh ph? huynh trong request; endpoint n?y kh?ng t?o t?i kho?n.
