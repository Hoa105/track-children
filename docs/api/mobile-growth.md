# Theo dõi tăng trưởng

Backend FastAPI/PostgreSQL và màn Theo dõi trong `mobile/`. Contract tăng trưởng:
[OpenAPI](mobile-growth.openapi.json). BMI lấy từ cặp cân nặng/chiều cao cùng ngày,
làm tròn hai chữ số theo ROUND_HALF_UP; không tự ghép ngày, đổi tư thế hoặc phân loại dinh dưỡng.

## Chạy backend và mobile

1. Cài `backend/requirements.txt`, khởi động PostgreSQL và áp dụng migrations
   `001`–`007` bằng `scripts/migrate.ps1 -Target backend`.
2. Cấu hình `DATABASE_URL`, `AUTH_SECRET` ngẫu nhiên tối thiểu 32 ký tự; không dùng
   secret kiểm thử cho ứng dụng thật. `.env.example` không chứa secret có thể dùng ngay.
3. Từ `backend/`, chạy `uvicorn app.main:app --env-file .env --reload` sau khi tạo `.env`.
4. Từ `mobile/`, chạy `flutter pub get`, sau đó
   `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1` cho Android emulator.
   Thiết bị thật cần URL truy cập được; bản release dùng HTTPS. HTTP chỉ được bật trong Android debug.
5. Đăng nhập tài khoản server đã có, chọn hoặc tạo hồ sơ trẻ, mở Theo dõi.

Workspace khi triển khai chỉ có auth demo, không có module auth backend được mô tả
ở cuộc trao đổi trước. Vì vậy phiên bản này bổ sung **phiên tối thiểu cho tài khoản
active đã tồn tại**: xác minh mật khẩu Argon2, JWT 15 phút, phiên 24 giờ, refresh
xoay token, logout và kiểm tra phiên trong DB. Không triển khai lại đăng ký/SMS OTP,
khôi phục mật khẩu hoặc lưu phiên qua lần mở app. Form đăng ký hiện tại vẫn thuộc demo.
Token chỉ ở bộ nhớ; đã bỏ tùy chọn ghi nhớ chưa được hỗ trợ khỏi màn đăng nhập.

Demo được xử lý cục bộ khi thông tin khớp tài khoản demo. Đăng nhập từ giao diện
với tài khoản khác gọi server; không có fallback sang demo khi server lỗi.
Dữ liệu demo/legacy không tự động nhập lên PostgreSQL. Cache hồ sơ server tách theo user ID;
mọi thao tác tăng trưởng thật cần phiên server. Tên trẻ không được dùng làm định danh API.

## API phụ thuộc

Tất cả body/response dùng camelCase; base path `/api/v1`.

| Endpoint | Body / kết quả |
|---|---|
| `POST /auth/login` | `{email,password}` → `{accessToken,refreshToken,tokenType,expiresIn,user:{id,fullName,email}}` |
| `POST /auth/refresh` | `{refreshToken}` → bộ token mới, không kéo dài hạn phiên |
| `POST /auth/logout` | `{refreshToken}` → 204, thu hồi phiên tương ứng |
| `GET /auth/me` | Bearer JWT → `{id,fullName,email}` |
| `GET /children` | Bearer JWT → `{children:[ChildContext]}`, chỉ hồ sơ có quyền xem growth |
| `POST /children` | `{fullName,dateOfBirth,gender,gestationalWeeks?,birthWeightKg?}` → 201 ChildContext |
| `GET /children/{id}` | ChildContext của hồ sơ được phép xem |
| `PUT /children/{id}` | Body như POST, chỉ chủ hồ sơ được sửa → ChildContext |

ChildContext gồm `id,fullName,dateOfBirth,gender,growthAccess`. gender là male/female;
growthAccess là view/edit. Đổi ngày sinh sẽ tính lại age_in_days của số đo active;
từ chối ngày sinh sau số đo đang tồn tại. Quyền sửa growth không tự cấp quyền sửa hồ sơ.
Profile API tối thiểu này chưa tải avatar hoặc quản lý lời mời/chia sẻ.

Đăng nhập sai 5 lần liên tiếp cho cùng email sẽ khóa thử 15 phút trong bảng
`account.mobile_login_limits`. Đây không phải bản thay thế toàn bộ contract auth/SMS cũ.

## Hành vi giao diện

- Theo dõi tải dữ liệu server khi mở; thêm/sửa trong sheet, dữ liệu cùng ngày được hiện sẵn.
  Chỉ những trường thay đổi được gửi. Muốn xóa dùng nút xóa trong lịch sử từng chỉ số.
- Chọn tư thế nằm/đứng khi nhập chiều cao. Lỗi lưu giữ nguyên form để thử lại;
  lưu lại cùng ngày không tạo thêm bản ghi active. Lưu từ Trang chủ dùng cùng API/cache.
- Bộ lọc tác động biểu đồ và lịch sử; tổng quan mới nhất lấy toàn bộ lịch sử.
- Xóa mềm lưu người thao tác. BMI biến mất khi thiếu cặp; tổng quan lùi về cặp còn hiệu lực gần nhất.
- Quyền view tắt thao tác sửa; backend vẫn kiểm tra quyền khi gọi API trực tiếp.
- Giữ dữ liệu tham chiếu WHO hiện có. Nếu tư thế không khớp quy tắc tuổi trong ứng dụng,
  ẩn đối chiếu chiều cao/BMI và hiện thông báo; vẫn hiển thị số đo thật.

## Chạy kiểm thử

Từ thư mục gốc, dùng database riêng, không dùng database ứng dụng:

```powershell
python -m pip install -r backend/requirements-dev.txt
docker run --name track-children-growth-test -e POSTGRES_USER=growth_test -e POSTGRES_PASSWORD=growth_test_local -e POSTGRES_DB=track_children_growth_test -p 127.0.0.1:55440:5432 -d pgvector/pgvector:pg16
.\scripts\test-growth.ps1
cd mobile
flutter pub get
flutter test
```

Fixture tự áp dụng migrations chưa chạy và reset dữ liệu giữa các ca. Chỉ chấp nhận
database có hậu tố `_growth_test`. Không chạy đồng thời hai bộ pytest dùng cùng database.
Không có `GROWTH_TEST_DATABASE_URL` thì integration test bị skip, không tính là đạt.

Đo tải riêng (root): đặt `PYTHONPATH=backend`, `GROWTH_TEST_DATABASE_URL` như trên,
`GROWTH_PERF=1`, chạy `python -m pytest backend/tests/growth/test_performance.py -q`.
Kết quả ghi vào [baseline JSON](mobile-growth-performance.json); không phải SLA production.

Kiểm thử Dart qua HTTP thật, sau khi pytest/migrations đã chạy (terminal thứ nhất tại root):

```powershell
$env:PYTHONPATH = "$PWD/backend"
$env:GROWTH_TEST_DATABASE_URL = 'postgresql://growth_test:growth_test_local@127.0.0.1:55440/track_children_growth_test'
python -m tests.growth.live_server
```

Terminal thứ hai từ `mobile/`:

```powershell
flutter test test/growth_live_test.dart --dart-define=GROWTH_LIVE_TEST=true --dart-define=API_BASE_URL=http://127.0.0.1:8009/api/v1
```

Live server chỉ bind localhost và chỉ provision tài khoản fixture trong database test.
Không chạy pytest reset DB trong khi live test đang chạy. Dừng server bằng Ctrl+C;
container test được giữ lại cho các lần sau, có thể dừng bằng `docker stop track-children-growth-test`.
