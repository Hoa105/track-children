# Đăng ký app theo database mới

Màn hình Flutter dùng API `/api/v1`, tương ứng migrations `009` và `010`.
Không ghi trực tiếp database và không gửi các trường cũ `username`, `fullName`,
`relationship`, `consents` trong request đăng ký.

## Luồng email / số điện thoại

1. Nhập tên hiển thị tùy chọn (mặc định `Phụ huynh`, tối đa 150 ký tự),
   chọn email hoặc số điện thoại, mật khẩu 8–64 ký tự và xác nhận mật khẩu.
2. Chọn vai trò: `mother`, `father`, `grandfather`, `grandmother`, `other_guardian`.
3. Đọc tài liệu từ `GET /legal-documents?context=registration` và đồng ý điều khoản.
4. `POST /auth/register` gửi `displayName`, đúng một trong `email` / `phone`,
   `password`, `defaultRelationship`, `acceptedTerms`.
5. Backend tạo tài khoản `pending`, lưu `consented_at` và mã băm trong `account.auth_codes`.
6. Nhập OTP 6 số. `/auth/register/verify` kích hoạt tài khoản và trả phiên đăng nhập.
   App lưu refresh token bằng secure storage rồi mở màn hình hồ sơ bé.

Đóng hộp OTP rồi bấm đăng ký lại với cùng dữ liệu sẽ tiếp tục phiên xác minh
trong bộ nhớ màn hình, không tạo yêu cầu đăng ký mới. Sau gửi lại, app giữ
`verificationId` và `registrationToken` mới. Server quyết định thời gian chờ,
giới hạn gửi và số lần nhập sai; app đọc header `Retry-After` khi bị giới hạn.
Phiên xác minh không còn hợp lệ thì đóng hộp OTP và bấm đăng ký lại.

## Google / Apple

Hai nút mở giao diện chọn/xác nhận tài khoản gốc của Google/Apple trước.
Google xóa lựa chọn SDK đã lưu trước khi mở lại giao diện chọn tài khoản;
Apple hiển thị giao diện tài khoản do hệ điều hành/nhà cung cấp kiểm soát.
App không thể tự liệt kê các Apple ID trên thiết bị.

Sau khi chọn tài khoản, app hiển thị tài khoản vừa chọn và ô đồng ý điều khoản
chưa được tích sẵn, kèm nút đọc tài liệu. Bấm tiếp tục mới hiện bước chọn vai trò
với bé; không có vai trò được chọn mặc định. Chỉ sau khi chọn vai trò và bấm
hoàn tất, app mới gửi token thật đến `/auth/social`, kèm vai trò và tên đã nhập
(nếu có). Hủy ở bước điều khoản/vai trò không gửi yêu cầu tạo tài khoản.
Tài khoản mới mở hồ sơ bé; tài khoản đã có đi theo luồng đăng nhập.
Apple lấy challenge từ backend trước khi mở nhà cung cấp.

Cần cấu hình OAuth cả backend và bản build mobile. Google dùng
`GOOGLE_SERVER_CLIENT_ID` và `GOOGLE_IOS_CLIENT_ID` nếu chạy iOS. Apple trên Android
cần `APPLE_SERVICE_ID`, `APPLE_REDIRECT_URI` và callback hợp lệ; backend cần audience,
khóa và thông tin Apple tương ứng. Không thể kiểm chứng đăng nhập nhà cung cấp thật
chỉ bằng widget test.

## Kiểm tra

```powershell
cd mobile
flutter test test/registration_test.dart test/social_registration_flow_test.dart test/auth_widgets_test.dart test/auth_service_test.dart test/demo_auth_test.dart
```

Backend có `tests/test_registration_v2.py` và `tests/test_social_auth.py`.
Chỉ chạy với `AUTH_TEST_DATABASE_URL` trỏ tên database kết thúc `_test`;
fixtures tạo database dùng một lần, áp migrations và xóa sau kiểm thử.

Khi `APP_ENV=local` và `AUTH_OTP_PREVIEW=true`, hộp OTP hiển thị mã thử nghiệm;
email/SMS không được gửi. Muốn kiểm tra giao nhận thật, tắt preview và cấu hình
nhà cung cấp email/SMS. Không bật preview trong production.
