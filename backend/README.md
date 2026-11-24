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

## Growth tracking

See [setup and API usage](../docs/api/mobile-growth.md),
[OpenAPI contract](../docs/api/mobile-growth.openapi.yaml),
[test plan](../docs/api/mobile-growth-test-plan.md) and
[test results](../docs/api/mobile-growth-test-results.md).

Set `DATABASE_URL` and a random `AUTH_SECRET` of at least 32 characters before
using protected routes. For local startup from `backend/`, copy `.env.example`
to `.env`, configure it, then run `uvicorn app.main:app --env-file .env --reload`.
Docker Compose reads `AUTH_SECRET`/`CORS_ORIGINS` from the shell or root `.env`.

## Database migrations

Start the local PostgreSQL containers from the repository root, then run:

```powershell
.\scripts\migrate.ps1 -Target backend -ApproveAuthCompaction
```

Migrations are stored in `backend/migrations/` and are applied in filename
order. The `public.schema_migrations` table records each applied migration.
Pending migrations and their ledger entries commit in one transaction per database.
The approval switch is required only while auth migrations 025/026 are pending;
an up-to-date database can be checked again without it. Run
`Get-Help ./scripts/migrate.ps1 -Full` for target and bootstrap options.
Auth regression checks: `./scripts/test-auth-full.ps1`.

## Dữ liệu demo cho mobile

Chưa có đăng nhập thật. Để mobile đồng bộ sổ tiêm, seed tài khoản + hồ sơ trẻ
có uuid cố định khớp `mobile/lib/services/api_config.dart`:

```powershell
python -m app.seed.demo
```

Mobile gọi `http://10.0.2.2:8000` trên Android emulator, `http://localhost:8000`
ở nơi khác; thiết bị thật: `flutter run --dart-define=API_BASE_URL=http://<IP LAN>:8000`
(và chạy uvicorn với `--host 0.0.0.0`).

## Kết quả kiểm thử

[Báo cáo kết quả](../docs/test-results/README.md).

Sau khi đổi seed lịch tiêm, xuất lại bản dự phòng offline cho mobile:
`python -m app.seed.export_mobile_schedule`.

`/dev/profiles` chỉ bật khi `APP_ENV=local` và `DEV_AUTH=true`, yêu cầu JWT
của chính phụ huynh trong request; endpoint này không tạo tài khoản.

## Admin authentication

[Setup and API](../docs/api/admin-auth.md), [OpenAPI YAML](../docs/api/admin-auth.openapi.yaml).
Implementation: `app/features/auth/admin/`. Requires migrations through 011.

## Notifications

Apply migration `027_notification_delivery.sql` using the existing migration runner.
The inbox API is `/api/v1/notifications`, with `/read`, `/preferences`, `/device`
and `/growth/{child_id}/{metric}` endpoints. Reading the inbox reconciles reminders;
run `python -m scripts.notification_worker` for reminders while the app is closed.
Alternatively run `python -m scripts.deliver_notifications` every minute.

Use Application Default Credentials for a Firebase service account authorized to send
FCM messages. Set `GOOGLE_APPLICATION_CREDENTIALS` to its local JSON path; never commit
the key. Docker: set `FIREBASE_SERVICE_ACCOUNT_FILE`, then run
`docker compose --profile notifications up -d --build notification-worker`.
Without credentials, the durable inbox still works and push stays queued.

Mobile Firebase options can be provided through `--dart-define-from-file` with keys
`FIREBASE_APP_ID`, `FIREBASE_API_KEY`, `FIREBASE_SENDER_ID`, `FIREBASE_PROJECT_ID`,
and `FIREBASE_IOS_BUNDLE_ID` (iOS). Use app IDs matching the Android applicationId
and iOS bundle identifier. For iOS, enable Push Notifications in Xcode/signing and
upload the APNs authentication key in Firebase. These project/signing resources
must be provided by the application owner. Enable push in the notification settings
screen to request device permission. Android foreground messages refresh the inbox;
iOS additionally uses the native foreground presentation.

Default: 08:00 in the saved timezone, one assessment notice on milestone opening
and one follow-up after seven days; late discovery produces only the applicable
stage. Measurement reminders use a configurable 30-day personal interval, one
follow-up after seven days, and per-metric snooze/disable. A new measurement changes
the due date. The inbox retains resolved notices. Turning off push preserves history.
Existing vaccination and sharing notices remain available from their current sources.

The worker retries transient sends up to five attempts and disables unregistered
tokens. An interrupted send can be retried after a provider acceptance; FCM does not
provide exactly-once delivery. Android notification tags reuse the same notification ID.
Validate background, terminated, permission-denied, account-switch, and APNs behavior
on registered physical devices before enabling the worker in production.

### Thiết lập Firebase lần đầu (ưu tiên Android)

1. Mở [Firebase Console](https://console.firebase.google.com/), tạo project và ghi lại Project ID.
   Không cần bật Analytics để triển khai luồng nhắc này.
2. Trong Project settings → General → Your apps, thêm ứng dụng Android.
   Package mặc định hiện tại là `com.example.track_children`; nếu đã cấu hình
   `applicationId` riêng trong `android/key.properties` thì dùng đúng giá trị đó.
3. Tải `google-services.json`, đặt tại `mobile/android/app/google-services.json`.
   Gradle sẽ tự áp dụng Google Services khi có file. File này cần cho Firebase khởi tạo
   ở tiến trình Android khi ứng dụng đóng. Hướng dẫn chính thức:
   [Firebase Android setup](https://firebase.google.com/docs/android/setup).
4. Với cấu hình native Android trên, không cần truyền thêm Dart defines.
   Nếu dùng options cho iOS, sao chép `mobile/firebase-config.example.json` thành
   `mobile/firebase-config.local.json` và điền thông tin của ứng dụng iOS tương ứng.
   `FIREBASE_APP_ID` là App ID của từng nền tảng, không phải Project ID.
   Chạy trong thư mục mobile: `flutter run --dart-define-from-file=firebase-config.local.json`.
5. Trong Project settings → Service accounts → Firebase Admin SDK, tạo private key
   và lưu trên máy backend, ví dụ `backend/firebase-service-account.json`.
   Thiết lập `GOOGLE_APPLICATION_CREDENTIALS` trỏ tới đường dẫn tuyệt đối của file.
   Chỉ dùng khóa này ở backend. Không chép vào assets/mobile. Tham khảo
   [Admin SDK setup](https://firebase.google.com/docs/admin/setup).
6. Cài `backend/requirements.txt`, áp dụng migration 027 rồi chạy worker như hướng dẫn trên.
   Đăng nhập app, mở Thông báo → Cài đặt → bật nhận thông báo và bấm Lưu.
   Để kiểm tra nhanh có thể đặt giờ nhắc về một giờ đã qua trong ngày.
7. Kiểm tra lần lượt khi app mở, chuyển xuống nền và đóng app thông thường.
   Hoàn thành bài đánh giá hoặc ghi số đo mới rồi xác nhận các lần nhắc cũ dừng lại.

Với iOS: đăng ký thêm app có bundle ID khớp Xcode (hiện là `com.example.uiChildcare`),
thêm `GoogleService-Info.plist` vào target Runner trong Xcode, bật capability
Push Notifications và Background Modes → Remote notifications, cấu hình signing,
rồi tải khóa APNs lên Firebase Cloud Messaging. Thực hiện trên macOS với tài khoản
Apple Developer và kiểm tra trên thiết bị được ký hợp lệ.
[Hướng dẫn FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/client).
