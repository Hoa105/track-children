# Mobile App — Track Children (Bé Lớn Khôn)

Ứng dụng Flutter cho phụ huynh và người chăm sóc trẻ.

Bộ dữ liệu kiểm thử đồng bộ: xem [tài khoản mẫu, kịch bản kiểm tra và phạm vi mô phỏng](docs/demo-data.md). Trong app, mở **Cài đặt → Dữ liệu kiểm thử** để xem hoặc khôi phục bộ mẫu.

## 1. Cài đặt

```powershell
cd mobile
flutter pub get
```

*(Tùy chọn) Kiểm tra môi trường Flutter và thiết bị:*
```powershell
flutter doctor
flutter devices
```

## 2. Chạy ứng dụng

### Auth trên Chrome

Auth trên web mặc định gọi `http://localhost:8000/api/v1`.
Nếu chạy backend bằng Docker Compose, thêm vào `.env` ở **gốc repository**:

```dotenv
CORS_ORIGINS='["http://localhost:5174","http://127.0.0.1:5174"]'
```

Sau đó áp dụng lại cấu hình bằng `docker compose up -d --no-deps backend`.
Compose mặc định chạy `APP_ENV=production`, nên cần khai báo origin cụ thể như trên.
Nếu chạy backend trực tiếp ở môi trường local, có thể dùng `APP_ENV=local`
và khởi động lại để cho phép CORS từ localhost ở các cổng dev.
Lỗi CORS có thể hiện thành “Không thể kết nối” trên app dù `/health` vẫn trả `200`.
Nếu API auth trả `404` sau khi cập nhật mã nguồn, build lại image backend:
`docker compose up -d --build --no-deps backend` (Compose không mount mã nguồn trực tiếp).

Lưu ý: các biến `${...}` của Compose lấy từ `.env` ở gốc repository,
không tự lấy từ `backend/.env`. Với kiểm thử local dùng API và OTP preview,
cấu hình ở `.env` gốc: `APP_ENV=local`, `AUTH_SECRET` (ít nhất 32 ký tự),
`AUTH_OTP_PREVIEW=true`, `AUTH_SKIP_OTP=false` và
`LEGAL_DOCUMENTS_PATH=/app/local-config/legal-documents.local.json`.
Compose mount file tài liệu local chỉ đọc; có thể đổi file nguồn bằng
`LEGAL_DOCUMENTS_FILE`. Tài liệu `local-test-1` chỉ dành cho kiểm thử nội bộ.
Ở chế độ local, backend cho phép cổng localhost ngẫu nhiên của `flutter run`.
OTP preview hiện trong hộp thoại xác minh, chưa gửi email/SMS thật.
Chọn **Mobile Chrome (API)** trong VS Code hoặc chạy trong thư mục `mobile`:

```bash
flutter run -d chrome --web-port 5174 --dart-define=DEMO_MODE=false
```

Sau khi đổi cấu hình, dừng và chạy lại app.

Nếu sau reload gặp `AppInspector ... Runtime.evaluate ... Cannot find context
with specified id`, debugger có thể đang giữ JavaScript context cũ của Chrome.
Dừng phiên chạy hiện tại hoàn toàn rồi chạy lại; tránh bấm refresh trình duyệt
đồng thời với hot restart. Không cần xóa dữ liệu ứng dụng hay `flutter clean`
chỉ vì log này.

Để review giao diện mà không dùng Dart debugger, chọn **Mobile Chrome (UI Profile)**
trong VS Code (có trong cấu hình gốc và thư mục `mobile`) hoặc chạy:

```bash
flutter run -d chrome --profile --web-port 5174 --dart-define=DEMO_MODE=false
```

Profile không hỗ trợ hot reload/breakpoint Dart; sau khi sửa mã cần dừng và chạy lại.
Đây là cách tránh lỗi kết nối debugger khi kiểm thử UI, không phải bản vá DWDS.

Hiện mặc định dùng **API xác thực thật**, cần backend tại cổng `8000`.
Android emulator dùng `http://10.0.2.2:8000/api/v1`. Với Android thật kết nối USB,
chạy `adb reverse tcp:8000 tcp:8000`, sau đó:

```powershell
flutter run --device-user 0 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Backend cần migration, `AUTH_SECRET`, tài liệu pháp lý và webhook SMS để đăng ký/OTP.
Xem [hướng dẫn backend](../backend/README.md).

Để dùng **chế độ demo**, chạy `flutter run --dart-define=DEMO_MODE=true`.
Đăng nhập `demo@trackchildren.vn` / `TreXanh123` để xem Bảo An và Gia Linh;
hoặc `bo@trackchildren.vn` / `TreXanh123` để xem Minh Khang.
Đăng ký mới lưu cục bộ, OTP mẫu là `123456`; tài khoản mới chưa có hồ sơ bé.
Mỗi lần khởi động app cần đăng nhập lại. Các chỉnh sửa dữ liệu vẫn lưu trên thiết bị.
Nếu đã sửa bộ mẫu, dùng **Cài đặt → Dữ liệu kiểm thử → Khôi phục bộ dữ liệu test**.

Để bật lại xác thực API:
```powershell
flutter run --dart-define=DEMO_MODE=false --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```
Sau khi đổi chế độ, dừng và chạy lại ứng dụng.

- **Chạy trên thiết bị mặc định (hoặc máy ảo đang mở):**
  ```powershell
  flutter run
  ```

- **Chạy chỉ định thiết bị cụ thể:**
  ```powershell
  # Chạy trên Android, cài và mở app cho Owner (user 0):
  flutter run -d <android-device-id> --device-user 0

  # Preview nhanh trên trình duyệt Chrome:
  flutter run -d chrome

  # Chạy trên Windows desktop:
  flutter run -d windows
  ```

- **Chạy màn hình preview hồ sơ bé:**
  ```powershell
  flutter run -t tool/child_profile_preview.dart
  ```

*Phím tắt khi đang chạy:*
- `r`: Hot Reload (cập nhật UI tức thì)
- `R`: Hot Restart (khởi động lại app và nạp lại state)
- `q`: Dừng ứng dụng

## 3. Kiểm thử & Phân tích

### Android báo `Error type 3: Activity class ...MainActivity does not exist`

Khi chạy trên máy thật bằng VS Code, chọn cấu hình **Mobile Android (user 0)** rồi nhấn F5. Cấu hình có sẵn khi mở thư mục gốc hoặc riêng thư mục `mobile`, và truyền `--device-user 0` cho Flutter để kiểm tra, cài đặt và mở app cho cùng một user, kể cả sau khi gỡ app rồi cài lại. Chọn thiết bị Android trước khi chạy cấu hình này. Với terminal, luôn dùng `flutter run -d <android-device-id> --device-user 0`; lệnh `flutter run` không kèm user vẫn có thể gặp lại lỗi trên máy nhiều user.

Nếu thiết bị có nhiều user (Owner/Khách), APK có thể được cài cho user khác với user đang chạy. Kiểm tra bằng:

```powershell
adb shell am get-current-user
adb shell pm list users
adb shell dumpsys package com.example.track_children
```

Nếu user hiện tại là `0` nhưng package có `User 0: ... installed=false`, đăng ký lại package có sẵn cho Owner rồi chạy Flutter với user cụ thể:

```powershell
adb shell cmd package install-existing --user 0 com.example.track_children
flutter run -d <android-device-id> --device-user 0
```

Nếu package chưa có trên thiết bị, cài APK cho đúng user:

```powershell
adb install --user 0 -r build/app/outputs/flutter-apk/app-debug.apk
```

Thay `0` bằng user đang dùng nếu cần; không cần gỡ ứng dụng hay xóa dữ liệu.

- **Chạy toàn bộ unit & widget test:**
  ```powershell
  flutter test
  ```

- **Chạy riêng từng file test:**
  ```powershell
  flutter test test/home_layout_test.dart
  flutter test test/child_profile_test.dart
  ```

- **Kiểm tra cú pháp & linter:**
  ```powershell
  flutter analyze
  ```
