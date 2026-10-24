# Database

SQL nguồn backend nằm trong [`backend/migrations`](../../backend/migrations/), SQL nguồn AI nằm trong [`ai-service/migrations`](../../ai-service/migrations/). Runner: [`scripts/migrate.ps1`](../../scripts/migrate.ps1).

## Quy trình cập nhật schema

Sau khi viết migration SQL mới, không sửa hoặc chạy lại migration đã có trong
`public.schema_migrations`. Tạo file có số thứ tự tiếp theo, ví dụ
`backend/migrations/013_add_example.sql`, rồi thực hiện:

### PowerShell

```powershell
docker compose up -d db
.\scripts\migrate.ps1 -Target backend
```

### Git Bash

```bash
docker compose up -d db
pwsh ./scripts/migrate.ps1 -Target backend
```

Kiểm tra migration đã được ghi nhận:

```bash
docker compose exec -T db psql \
  -U track_children \
  -d track_children \
  -c "SELECT version, applied_at FROM public.schema_migrations ORDER BY version;"
```

Kiểm tra bảng và cột sau khi cập nhật:

```bash
docker compose exec -T db psql \
  -U track_children \
  -d track_children \
  -c "\\dt account.*"

docker compose exec -T db psql \
  -U track_children \
  -d track_children \
  -c "\\d+ account.auth_codes"
```

Sau đó refresh/reconnect database trong TablePlus. Nếu migration lỗi, runner sẽ
dừng và không ghi version vào `schema_migrations`; sửa bằng migration mới hoặc
khôi phục bản backup trước khi chạy lại. Không xóa volume Docker để xử lý lỗi,
vì có thể làm mất dữ liệu database.

Auth dùng `009_auth_database_simplification.sql` để hợp nhất cấu trúc tài khoản.
`010_social_auth.sql` là phần mở rộng đăng nhập xã hội ngoài 5 bảng auth lõi.
`011_admin_login.sql` chỉ giữ lại lịch sử migration; `012_auth_schema_alignment.sql`
dọn các bảng role/permission cũ trên database đã từng chạy migration 011.
`013_merge_auth_code_tables.sql` hợp nhất các bảng mã xác minh/reset cũ vào
`account.auth_codes`.

Với database đã áp dụng 009/010, chỉ chạy migration còn thiếu theo lịch sử
`public.schema_migrations`; không chạy lại reset 009 trên dữ liệu hiện có.

Kết quả kiểm thử đã lưu tại [báo cáo kết quả](../test-results/README.md).
