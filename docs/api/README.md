# API

API contracts and integration documentation.

## Mobile growth

[OpenAPI 3.1 JSON](mobile-growth.openapi.json) — contract dự kiến cho màn Theo dõi:
cân nặng, chiều cao, vòng đầu và BMI. Có API đọc lịch sử/tổng quan, lưu số đo
theo ngày và xóa mềm từng chỉ số. Import vào Swagger Editor hoặc Postman.
Trạng thái: **thiết kế, chưa triển khai backend**; phụ thuộc API hồ sơ trẻ.

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
