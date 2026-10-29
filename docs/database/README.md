# Hướng dẫn quản lý schema và dữ liệu mẫu

Các lệnh dưới đây dùng PowerShell, bắt đầu tại thư mục gốc dự án. Cần Docker
Desktop hoạt động; lệnh seed cần môi trường `.venv` đã cài dependencies backend.

## 1. Tạo schema trên database mới

Khởi động hai database và chạy toàn bộ migration:

```powershell
docker compose up -d db ai-db
.\scripts\migrate.ps1 -Target all
```

Hoặc chỉ tạo các schema thuộc một database:

```powershell
# Backend: account, child, growth, health, ...
docker compose up -d db
.\scripts\migrate.ps1 -Target backend

# AI: các schema trong database AI riêng
docker compose up -d ai-db
.\scripts\migrate.ps1 -Target ai
```

Để thêm một schema mới, tạo migration có số thứ tự tiếp theo trong
[`backend/migrations`](../../backend/migrations/) hoặc
[`ai-service/migrations`](../../ai-service/migrations/), chứa
`CREATE SCHEMA IF NOT EXISTS <ten_schema>;` và DDL các bảng cần thiết, rồi
chạy runner với target tương ứng. Không sửa migration đã áp dụng.

## 2. Cập nhật schema hiện có

Viết thay đổi vào migration mới, sau đó chọn một lệnh:

```powershell
# Cập nhật cả hai database
.\scripts\migrate.ps1 -Target all

# Chỉ database backend
.\scripts\migrate.ps1 -Target backend

# Chỉ database AI
.\scripts\migrate.ps1 -Target ai
```

Để chỉ thay đổi một schema (ví dụ `growth`), migration mới chỉ chứa DDL cho
schema đó, rồi chạy `-Target backend`. Runner **không có tham số lọc từng
schema**: mọi migration chưa áp dụng trong target đều được chạy theo thứ tự.
Kiểm tra các file đang chờ trước khi chạy; không bỏ qua migration phụ thuộc.

Runner theo dõi lịch sử trong `public.schema_migrations`, bỏ qua file đã chạy
và thực hiện mỗi file trong một transaction. Kiểm tra lịch sử:

```powershell
docker compose exec -T db psql -U track_children -d track_children -c "SELECT version, applied_at FROM public.schema_migrations ORDER BY version;"
docker compose exec -T ai-db psql -U track_children -d track_children_ai -c "SELECT version, applied_at FROM public.schema_migrations ORDER BY version;"
```

Nếu database đã tạo thủ công từ migration 001 nhưng chưa có lịch sử, dùng
`-BootstrapExisting` cho target tương ứng sau khi đối chiếu cấu trúc. Tùy chọn
này chỉ đánh dấu migration 001; không tự nhận diện các migration khác đã chạy.
Sao lưu trước khi thay đổi dữ liệu; không xóa volume để sửa lỗi migration.

## 3. Chạy dữ liệu mẫu

Chạy migration trước khi seed. Các lệnh dưới đây chỉ dùng cho database local.
Chuẩn bị từ thư mục gốc:

```powershell
$env:APP_ENV = 'local'
$env:DATABASE_URL = 'postgresql://track_children:track_children_dev@localhost:5433/track_children'
Set-Location backend
```

### Chạy toàn bộ bộ seed hiện có

```powershell
# Dữ liệu mẫu account
..\.venv\Scripts\python.exe -m app.seed.local_auth
if ($LASTEXITCODE -ne 0) { throw 'Seed account failed' }

# Tài khoản demo và hồ sơ trẻ mẫu (account + child)
..\.venv\Scripts\python.exe -m app.seed.demo
if ($LASTEXITCODE -ne 0) { throw 'Seed demo failed' }

# Growth cho cả ba hồ sơ demo
foreach ($sampleChildId in @(
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000102',
    '00000000-0000-4000-8000-000000000103'
)) {
    ..\.venv\Scripts\python.exe -m app.seed.growth --child-id $sampleChildId
    if ($LASTEXITCODE -ne 0) { throw "Seed growth failed: $sampleChildId" }
}
```

Đây là toàn bộ **bộ seed tùy chọn đang có**, không phải dữ liệu mẫu cho mọi
schema. Các schema khác và database AI chưa có bộ seed mẫu riêng. Dữ liệu danh
mục trong migration (ví dụ vaccine/lịch tiêm) được nạp khi chạy migration;
không chạy lại migration cũ để cập nhật danh mục, hãy viết migration mới.

### Chạy riêng từng schema

Các lệnh này cũng chạy từ thư mục `backend`, với biến môi trường ở trên:

| Schema | Lệnh |
|---|---|
| `account` | `..\.venv\Scripts\python.exe -m app.seed.local_auth` |
| `child` và tài khoản demo phụ thuộc | `..\.venv\Scripts\python.exe -m app.seed.demo` |
| `growth` cho một trẻ có sẵn | `..\.venv\Scripts\python.exe -m app.seed.growth --child-id <UUID_CUA_TRE>` |

Thay `<UUID_CUA_TRE>` bằng UUID thật, không giữ dấu `< >`. Seed growth cần
migration 015 và hồ sơ trẻ chưa xóa; không tạo tài khoản hay hồ sơ mới.

Các seed hiện tại thêm dữ liệu còn thiếu và bỏ qua bản ghi đã tồn tại; chạy
lại không ghi đè để cập nhật giá trị mẫu cũ. Growth thêm tối đa 39 số đo mỗi
trẻ, chỉ lấy các mốc không ở tương lai, không tạo đánh giá/Z-score giả;
`evaluations` cần được tính bằng `anthro`. Muốn sửa dữ liệu mẫu đã có,
viết seed cập nhật riêng với điều kiện nhận diện chính xác dữ liệu mẫu.

Sau khi chạy xong, trở lại thư mục gốc:

```powershell
Set-Location ..
```
