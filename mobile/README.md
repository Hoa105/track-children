# Mobile App — Track Children (Bé Lớn Khôn)

Ứng dụng Flutter cho phụ huynh và người chăm sóc trẻ.

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
