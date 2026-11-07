# API

API contracts and integration documentation.

## Assessment — đánh giá phát triển của trẻ

- [Mobile assessment](mobile-assessment.openapi.yaml): 6 thao tác xem tổng quan, lịch sử,
  bắt đầu/tiếp tục bài, xem bài, lưu đáp án và hoàn thành bài.
- [Admin assessment](admin-assessment.openapi.yaml): 31 thao tác quản lý bộ câu hỏi,
  nội dung và phiên bản, công bố/ẩn/khôi phục, kiểm duyệt, nhập/xuất, lịch sử và thử kết quả.

Hai đặc tả phản ánh backend hiện tại, có đầy đủ tiền tố đường dẫn và xác thực Bearer JWT.
Mobile yêu cầu quyền chia sẻ `assessment` mức `view`/`edit`; admin yêu cầu `assessment.read`.
Mobile dùng trường snake_case; các model admin dùng camelCase, còn phản hồi hành động,
nhập/xuất, lịch sử và thử kết quả dùng snake_case theo service.
Kết quả giúp theo dõi mốc phát triển, không thay thế sàng lọc hoặc chẩn đoán.

[Kết quả kiểm thử local qua HTTP và PostgreSQL](assessment-test-results.md).

Tạo lại đặc tả và kiểm tra từ thư mục gốc dự án:

```powershell
.\.venv\Scripts\python.exe scripts/export-assessment-openapi.py
$env:PYTHONPATH = "$PWD/backend"
.\.venv\Scripts\python.exe -m pytest backend/tests/test_assessment_openapi.py -q
```

## Mobile teething

Mọc răng dùng quyền chia sẻ độc lập `teething` từ migration
`020_teething_permissions.sql`. Chủ hồ sơ luôn có quyền `edit`; người chăm sóc
nhận một trong `none`, `view`, `edit`. Xem hợp đồng quản lý thành viên và lời mời
tại [mobile-sharing.openapi.yaml](mobile-sharing.openapi.yaml).

API v2 requires migration `019_teething_versions.sql` after `018` and a matching
mobile release. GET/PUT return an opaque UUID `version`. PUT requires
`expectedVersion: null` to create, or the last observed version to update.
DELETE sends `?expectedVersion=<version>`; omitting it only succeeds when the
record is already absent. A stale version returns HTTP 409 without changing data;
reload and review before retrying. Older clients must be updated before writing.
The device sends its current UTC offset on every PUT; eruption dates remain
calendar dates and are never converted into timestamps.
Each record also returns nullable `note`. PUT accepts an optional note of up to
1000 characters, trims surrounding whitespace, and clears the note for null or
blank input. Omit `note` to preserve it on update. The existing database column
is reused, so notes require no additional migration.

Run backend unit tests from `backend` with
`python -m pytest tests/test_teething_contract.py`.
For database tests, set `TEETHING_TEST_DATABASE_URL` to a dedicated PostgreSQL
database whose name ends in `_teething_test`, then run
`python -m pytest tests/test_teething_integration.py`. The tests apply migrations
and remove only their own generated children and users.

[OpenAPI 3.1 YAML](mobile-teething.openapi.yaml) — hợp đồng đã triển khai cho
giao diện **Răng của bé**. API dùng Bearer JWT, mã răng sữa FDI và cung cấp thao
tác tải danh sách, ghi nhận/cập nhật ngày mọc, bỏ đánh dấu. Backend cần chạy
migration `018_primary_teeth_reference.sql`; mobile tự đồng bộ khi mở màn hình,
giữ cache cục bộ khi mất mạng. Tab **Tham khảo** tiếp tục dùng bảng lịch 0–60
tháng đóng gói trong ứng dụng và không gửi dữ liệu trẻ lên máy chủ.

## Mobile growth

[OpenAPI 3.1 YAML](mobile-growth.openapi.yaml) l? ??c t? ??c l?p cho API growth.
Ch?nh s?a tr?c ti?p file YAML; kh?ng c?n c?c t?i li?u growth ngu?n ?? x?a.

C?i dependency v? ki?m tra ??c t? t? th? m?c g?c d? ?n:

```powershell
.\.venv\Scripts\python.exe -m pip install -r backend/requirements-dev.txt
.\.venv\Scripts\python.exe docs/api/tools/validate_growth_openapi.py
```

Validator ki?m tra OpenAPI, references, examples, t?nh nh?t qu?n enum/reason
v? c?c tr??ng h?p d? li?u sai; kh?ng ki?m tra endpoint ?ang ch?y.

## Mobile auth

[OpenAPI 3.1 YAML](mobile-auth.openapi.yaml) — import vào Swagger Editor hoặc Postman.

[API xác thực phụ huynh](mobile-auth.md): đăng ký, SMS OTP, đăng nhập, refresh,
đăng xuất và thông tin tài khoản. Đã triển khai với migration `007_mobile_auth.sql`.

## Admin auth (`/admin/auth/*`)

[OpenAPI 3.1 YAML](admin-auth.openapi.yaml) is the implemented contract.
Setup and test commands: [admin-auth.md](admin-auth.md).

Implemented: `POST /admin/auth/login`, `POST /admin/auth/refresh`,
`GET /admin/auth/me`, `PATCH /admin/auth/me`, `POST /admin/auth/logout`,
`POST /admin/auth/change-password`.
Access JWT: 15 minutes, admin audience; refresh: rotating HttpOnly cookie,
8-hour absolute session. Roles/permissions are read from PostgreSQL.
Requires migration `011_admin_login.sql` after schema 009/010.

Password reset, invitations, session-management UI and the admin-management APIs
below remain planned. Their old schema assumptions are not the implemented contract.

## Quản lý quản trị viên (`/admin/admins/*`, quyền `admin.manage`)

| Method & path | Body | Ghi chú |
|---|---|---|
| `GET /admin/admins` | — | Danh sách + vai trò + lần đăng nhập gần nhất |
| `PATCH /admin/admins/{id}` | `{ role?, status? }` | Không cho tự sửa mình; DB chặn bỏ super admin active cuối cùng. Khóa → thu hồi mọi phiên |
| `POST /admin/admins/{id}/send-reset` | — | Gửi link đặt lại mật khẩu |
| `GET /admin/admins/invitations` | — | |
| `POST /admin/admins/invitations` | `{ email, fullName?, role }` | Hết hạn 7 ngày; `409` nếu email đã là admin hoặc đang có lời mời |
| `POST /admin/admins/invitations/{id}/resend` | — | Sinh token mới, gia hạn 7 ngày |
| `DELETE /admin/admins/invitations/{id}` | — | `status = 'cancelled'` |
| `GET /admin/roles` | — | Vai trò + danh sách quyền (ma trận) |

Mọi thao tác ghi đều ghi vào `admin.admin_audit_logs`.
