# Bộ dữ liệu test đồng bộ

Chạy app từ `mobile_2`. Dữ liệu hư cấu được tạo một lần, lưu trong SharedPreferences với khóa `synchronized_demo_v1`. Các lần mở sau giữ lại thay đổi; các khóa dữ liệu tăng trưởng cũ ngoài bộ test không bị xóa. Tuổi mẫu được tính theo ngày tạo dữ liệu, không đổi ngày sinh sau mỗi lần mở app.

## Đăng nhập

| Email | Mật khẩu ban đầu | Phụ huynh | Hồ sơ thuộc tài khoản |
|---|---|---|---|
| `demo@trackchildren.vn` | `TreXanh123` | Nguyễn Thị Hoa · Mẹ | Bảo An (trai, 8 tháng), Gia Linh (gái, 30 tháng) |
| `bo@trackchildren.vn` | `TreXanh123` | Trần Minh Đức · Bố | Minh Khang (trai, 14 tháng) |

Hai tài khoản thuộc **hai gia đình riêng** để kiểm tra không lẫn dữ liệu. Mỗi bé có 7 lần đo cân nặng, chiều cao, vòng đầu; BMI chỉ lấy các lần có cả cân nặng và chiều cao. ID cố định là `child_an`, `child_linh`, `child_minh`; sửa tên không đổi ID. Mỗi bé có 1 thành viên và 1 lời mời chờ, dữ liệu tổng quan chăm sóc và nhật ký riêng.

OTP trong luồng đăng ký/đổi số điện thoại dùng `123456`; không gửi SMS. Tài khoản mới được tạo cục bộ và có thể thêm hồ sơ bé mới không có số đo. Email/mật khẩu đã sửa sẽ được dùng cho lần đăng nhập sau, thay cho thông tin mẫu ban đầu.

## Nguồn dữ liệu dùng chung

- Đăng nhập, thông tin tài khoản, vai trò phụ huynh, mật khẩu test và tùy chọn thông báo/sinh trắc: bản ghi phụ huynh.
- Trang chọn bé, danh sách hồ sơ trong Cài đặt, tên/tuổi ở Home và biểu đồ WHO: cùng bản ghi bé, tham chiếu bằng ID.
- Số đo ở Home và trang Theo dõi: cùng lịch sử số đo của ID bé. Tăng trưởng mới được lưu cục bộ rồi thông báo để Home cập nhật. Cùng ngày thì số đo lưu sau được ưu tiên.
- Sửa ngày sinh/giới tính trong phần đối chiếu WHO cập nhật vào hồ sơ bé; sửa trong hồ sơ cũng được dùng khi mở lại biểu đồ.
- Chia sẻ từ hồ sơ bé hoặc Cài đặt: cùng danh sách thành viên/quyền/lời mời theo ID bé. Sửa quyền, thu hồi, tạo/hủy lời mời được lưu cục bộ.
- Ảnh bé chọn trong hồ sơ được lưu trong bộ test dạng base64 và hiển thị khi mở lại hồ sơ/Home.

## Kịch bản kiểm tra

1. Đăng nhập mẹ Hoa, chọn Bảo An. Đối chiếu tên, tuổi, giới tính, số đo mới nhất ở hồ sơ, Home và bốn tab Theo dõi.
2. Dùng mũi tên cạnh tên bé ở Home để chọn Gia Linh. Kiểm tra số đo/tuổi và đường WHO chuyển sang dữ liệu của bé gái.
3. Nhập số đo mới cho Gia Linh; quay về Home kiểm tra thẻ số đo, mức thay đổi và đường xu hướng. Bảo An phải giữ nguyên dữ liệu.
4. Sửa tên, ngày sinh, giới tính và ảnh bé ở hồ sơ. Kiểm tra Home, danh sách hồ sơ và WHO; lịch sử số đo không được mất khi sửa tên.
5. Sửa thông tin phụ huynh tại Cài đặt tài khoản; quay lại Cài đặt kiểm tra tên/email. Đổi mật khẩu test và đăng nhập lại bằng thông tin mới.
6. Tạo/hủy lời mời hoặc sửa quyền chia sẻ; mở lại từ lối vào khác và kiểm tra cùng danh sách. Bé khác phải giữ nguyên quyền/lời mời.
7. Tạo thêm bé mới; bé xuất hiện ở danh sách và có lịch sử rỗng. Nhập số đo đầu tiên, kiểm tra Home không hiện số liệu của bé khác.
8. Đăng xuất, đăng nhập bố Đức: chỉ thấy Minh Khang. Đăng nhập lại mẹ Hoa hoặc khởi động lại app: dữ liệu đã sửa vẫn còn.
9. Vào **Cài đặt → Dữ liệu kiểm thử** để xem ID, ngày sinh, số lượng bản ghi và khôi phục bộ mẫu qua hộp xác nhận.

## Phạm vi mô phỏng

Kho test phục vụ đồng bộ trên **một thiết bị**, chưa đồng bộ qua backend hoặc giữa hai máy. Các thao tác gửi email/SMS, chấp nhận lời mời để cấp quyền tài khoản khác, chuyển quyền sở hữu, xóa tài khoản thật, đăng nhập mạng xã hội, nhắc lịch hệ điều hành và khóa sinh trắc chưa được kết nối dịch vụ. Các màn hình xem thử của chúng không xác nhận tính đúng đắn của dịch vụ thật. Tùy chọn sinh trắc hiện chỉ lưu trạng thái mô phỏng.

Lượng sữa, tiêm chủng, mọc răng, hoạt động và nhật ký trên Home có dữ liệu tổng quan theo bé; các trang chức năng này chưa được triển khai trong `mobile_2`. Không coi các shortcut thông báo “sẽ được làm ở bước sau” là chức năng đã hoàn thành.

Thông tin đăng nhập được lưu dạng rõ **chỉ trong kho test hư cấu này**, không phải kiến trúc xác thực để dùng thật. Không nhập dữ liệu thật vào bộ test.

## Kiểm thử tự động

```powershell
flutter test test/demo_sync_test.dart
flutter test test/growth_screen_test.dart test/who_growth_chart_test.dart test/who_bmi_reference_test.dart
```

Các kiểm tra bao gồm lưu/đọc lại, sửa tên giữ ID, tách dữ liệu giữa bé và gia đình, cập nhật thông tin đăng nhập, chặn email trùng, ghi đồng thời, tạo hồ sơ rỗng và luồng giao diện Home → đổi bé → Theo dõi → lưu số đo → Home → Cài đặt.
