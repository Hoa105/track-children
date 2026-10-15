# Mobile App — Track Children (Bé Lớn Khôn)

Ứng dụng Flutter cho phụ huynh và người chăm sóc trẻ.

Bộ dữ liệu kiểm thử đồng bộ: xem [tài khoản mẫu, kịch bản kiểm tra và phạm vi mô phỏng](docs/demo-data.md). Trong app, mở **Cài đặt → Dữ liệu kiểm thử** để xem hoặc khôi phục bộ mẫu.

## 1. Cài đặt

```powershell
cd mobile_2
flutter pub get
```

*(Tùy chọn) Kiểm tra môi trường Flutter và thiết bị:*
```powershell
flutter doctor
flutter devices
```

## 2. Chạy ứng dụng

- **Chạy trên thiết bị mặc định (hoặc máy ảo đang mở):**
  ```powershell
  flutter run
  ```

- **Chạy chỉ định thiết bị cụ thể:**
  ```powershell
  # Chạy trên Android:
  flutter run -d <android-device-id>

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
