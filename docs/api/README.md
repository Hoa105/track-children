# API

API contracts and integration documentation.

## Mobile growth

[Setup and API usage](mobile-growth.md), [OpenAPI JSON](mobile-growth.openapi.json),
[test plan](mobile-growth-test-plan.md), [test results](mobile-growth-test-results.md).
Tracks weight, height/length, head circumference and same-day BMI per child.

## Admin auth (`/admin/auth/*`)

Web admin đang dùng bản mock có cùng chữ ký (`admin-web/src/core/authApi.js`). Khi backend
làm xong các endpoint dưới đây, chỉ cần thay thân các hàm trong file đó bằng `fetch`.

Không có endpoint tự đăng ký: super admin đầu tiên tạo bằng `scripts/create-admin.ps1`,
các admin khác được mời (`POST /admin/admins/invitations`).

| Method & path | Body | Kết quả | Ghi chú |
|---|---|---|---|
| `POST /admin/auth/login` | `{ email, password }` | `200 { accessToken, admin }` + cookie refresh | Sai email hay sai mật khẩu đều trả cùng một lỗi `401`. Sai 5 lần → `locked_until = now() + 15 phút`. `status = 'locked'` → `403` |
| `POST /admin/auth/refresh` | — (cookie) | `200 { accessToken }` | Xoay vòng refresh token (`admin_sessions`) |
| `POST /admin/auth/logout` | — | `204` | `revoked_at = now()` cho phiên hiện tại |
| `GET /admin/auth/me` | — | `{ id, email, fullName, role, permissions[] }` | Quyền lấy từ `role_permissions` |
| `POST /admin/auth/forgot-password` | `{ email }` | `204` (luôn luôn) | Tạo `admin_password_resets`, hết hạn sau 30 phút, gửi email |
| `GET /admin/auth/reset-password/{token}` | — | `{ email }` / `404` | |
| `POST /admin/auth/reset-password/{token}` | `{ password }` | `204` | Đánh dấu `used_at`, thu hồi mọi phiên của admin |
| `POST /admin/auth/change-password` | `{ currentPassword, newPassword }` | `204` | Thu hồi các phiên khác |
| `GET /admin/auth/invitations/{token}` | — | `{ email, fullName, role, invitedBy }` / `404` | Chỉ lời mời `pending`, chưa hết hạn |
| `POST /admin/auth/invitations/{token}/accept` | `{ fullName, password }` | `200 { accessToken, admin }` | Tạo `admin_users` + `admin_user_roles`, lời mời → `accepted` (1 transaction) |
| `GET /admin/auth/sessions` | — | `[{ id, userAgent, ip, lastUsedAt, current }]` | |
| `DELETE /admin/auth/sessions/{id}` | — | `204` | |

Token trong link mời / đặt lại mật khẩu: sinh ngẫu nhiên ≥ 32 byte, chỉ lưu SHA-256 trong DB.
Mật khẩu: bcrypt, tối thiểu 10 ký tự gồm chữ và số.

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
