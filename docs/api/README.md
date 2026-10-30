# API

API contracts and integration documentation.

## Mobile growth

[OpenAPI 3.1 JSON](mobile-growth.openapi.json) — contract v1.0.0 ngày 29/10/2026
cho giao diện growth mới, base `/api/v1`, Bearer phiên mobile hiện hành,
JSON camelCase. Gồm 6 operations: overview, metric detail/chart/history,
velocity, đọc ngày, upsert ngày và xóa mềm số đo. Import vào Swagger Editor/Postman.

Trạng thái: **IMPLEMENTED — đã có backend và Flutter remote**;
hướng dẫn môi trường, kiểm thử và giới hạn tại
[Growth runtime](../core_growth/GROWTH-RUNTIME-README.md). Chưa deploy production.
Status/mapping theo [contract 2.1](../core_growth/GROWTH-STATUS-CONTRACT.md);
đối chiếu màn hình với operation tại `x-screen-operations` trong JSON.
Ví dụ là dữ liệu tổng hợp kiểm tra contract, không phải dữ liệu trẻ thật hoặc
tuyên bố bộ reference đã VERIFIED. Chưa có API hồ sơ trẻ thì tích hợp phải
dùng child UUID được provision trong database test, không tự upload dữ liệu demo.

Kiểm tra từ thư mục gốc (môi trường Python có jsonschema/openapi-spec-validator):

```powershell
.\.venv\Scripts\python.exe docs/api/tools/validate_growth_openapi.py
```

JSON là artifact import độc lập, không cần các file core để resolve `$ref`.
Khi sửa status nguồn hoặc generator, dựng lại bằng
`docs/api/tools/build_growth_openapi.py` rồi chạy validator. Validator kiểm tra
OpenAPI, references, examples, enum/reason đồng bộ và các trường hợp dữ liệu sai;
không phải test endpoint đã hoạt động.

## Mobile auth

[OpenAPI 3.1 JSON](mobile-auth.openapi.json) — import vào Swagger Editor hoặc Postman.

[API xác thực phụ huynh](mobile-auth.md): đăng ký, SMS OTP, đăng nhập, refresh,
đăng xuất và thông tin tài khoản. Đã triển khai với migration `007_mobile_auth.sql`.

## Admin auth (`/admin/auth/*`)

[OpenAPI 3.1 JSON](admin-auth.openapi.json) is the implemented contract.
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
