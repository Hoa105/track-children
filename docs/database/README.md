# Database

SQL nguồn backend nằm trong [`backend/migrations`](../../backend/migrations/), SQL nguồn AI nằm trong [`ai-service/migrations`](../../ai-service/migrations/). Runner: [`scripts/migrate.ps1`](../../scripts/migrate.ps1).

Auth dùng `009_auth_database_simplification.sql` để hợp nhất cấu trúc tài khoản,
`010_social_auth.sql` bổ sung đăng nhập xã hội và `011_admin_login.sql` khôi phục
các bảng vai trò, quyền cho admin. Migration 011 không xóa tài khoản hoặc phiên hiện có.

Với database đã áp dụng 009/010, chỉ chạy migration còn thiếu theo lịch sử
`public.schema_migrations`; không chạy lại reset 009 trên dữ liệu hiện có.

Kết quả kiểm thử đã lưu tại [báo cáo kết quả](../test-results/README.md).
