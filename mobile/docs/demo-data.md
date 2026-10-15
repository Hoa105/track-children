# Bộ dữ liệu test đồng bộ

Chạy app từ `mobile`. Dữ liệu hư cấu được tạo một lần, lưu trong SharedPreferences với khóa `synchronized_demo_v1`. Các lần mở sau giữ lại thay đổi; các khóa dữ liệu tăng trưởng cũ ngoài bộ test không bị xóa. Tuổi mẫu được tính theo ngày tạo dữ liệu, không đổi ngày sinh sau mỗi lần mở app.

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

Lượng sữa, hoạt động và nhật ký trên Home mở bảng tổng quan theo bé; các trang ghi chép và chi tiết chức năng này chưa được triển khai. Bảng ghi rõ giới hạn. Tiêm chủng mở Sổ tiêm chủng riêng (xem bên dưới). Nút cộng mở bảng thao tác nhanh: “Thêm số đo” đi thẳng đến biểu mẫu tăng trưởng; ghi sữa và viết nhật ký hiện “Chưa khả dụng”. Thẻ cân nặng/chiều cao mở đúng tab theo dõi; mức thay đổi so với lần đo trước. Thông báo hiện trạng thái rỗng vì chưa kết nối nhắc lịch. Tab Khám phá hiện chỉ mở tổng quan giai đoạn tuổi.

Thông tin đăng nhập được lưu dạng rõ **chỉ trong kho test hư cấu này**, không phải kiến trúc xác thực để dùng thật. Không nhập dữ liệu thật vào bộ test.

## Kiểm thử tự động

```powershell
flutter test test/demo_sync_test.dart
flutter test test/home_actions_test.dart test/home_layout_test.dart
flutter test test/growth_screen_test.dart test/who_growth_chart_test.dart test/who_bmi_reference_test.dart
```

Các kiểm tra bao gồm lưu/đọc lại, sửa tên giữ ID, tách dữ liệu giữa bé và gia đình, cập nhật thông tin đăng nhập, chặn email trùng, ghi đồng thời, tạo hồ sơ rỗng và luồng giao diện Home → đổi bé → Theo dõi → lưu số đo → Home → Cài đặt.

## Mọc răng

Home → Mọc răng mở trang theo dõi của bé đang chọn: sơ đồ 20 răng sữa, tiến độ, ngày mọc đầu tiên, danh sách đã mọc và tối đa 3 nhóm răng sắp mọc. Chạm vào răng để ghi nhận/sửa ngày/bỏ đánh dấu (có xác nhận xóa). Ngày mọc nằm trong khoảng ngày sinh đến hôm nay; mỗi vị trí chỉ có một bản ghi. Dữ liệu lưu cục bộ theo ID bé, Home tự cập nhật số đếm.

Dữ liệu cũ thiếu trường `teeth` được coi là rỗng, không suy diễn từ chuỗi tổng quan cũ. Bộ mẫu mới/khôi phục có các răng theo mốc tuổi tham khảo; không tự thêm răng khi bé lớn lên. Nguồn mốc tuổi: https://www.mouthhealthy.org/all-topics-a-z/eruption-charts ; thông tin tham khảo: https://www.mouthhealthy.org/all-topics-a-z/teething . Đây không phải chẩn đoán.

Kiểm tra: thêm/sửa/xóa một răng → quay Home đối chiếu số đếm → đổi bé → đăng xuất/đăng nhập tài khoản bố → mở lại app. Bản ghi phải giữ nguyên và không lẫn bé/gia đình. Bé mới bắt đầu 0/20; ghi nhận đủ 20 thì nút thêm bị khóa.

Chạy: `flutter test test/teething_test.dart test/home_actions_test.dart test/home_layout_test.dart test/demo_sync_test.dart`.

## Sổ tiêm chủng

Giao diện đồng bộ với Home, Tăng trưởng và Mọc răng: kế thừa phông chữ từ Theme của ứng dụng, dùng AppColors/AppLayout, nền kem, nội dung trắng bo góc 24 và tab bo tròn nền xanh nhạt. Không có phông serif, gáy sổ, lề giấy hoặc dòng kẻ trang trí. Mỗi buổi vẫn nhóm theo ngày, nơi tiêm và danh sách vaccine, phân cách nhẹ để dễ đọc. Biểu mẫu và nút dùng cùng màu chủ đạo, ô nhập bo góc 16.

Home → Tiêm chủng mở **Theo tuổi** cho đúng ID bé đang chọn. Ba tab **Theo tuổi / Vắc-xin / Đã tiêm** cố định. Nút **＋ Thêm** trên thanh tiêu đề đồng bộ kiểu nút Số đo ở Tăng trưởng; thu thành **＋** khi cuộn xuống, mở lại khi cuộn lên, tôn trọng giảm chuyển động.

**Theo tuổi / Vắc-xin** dùng tổng quan gọn: số tím **đã ghi nhận / tổng đến tuổi hiện tại**, thanh tiến độ chuyển động và số mũi chưa ghi nhận màu cam có thể chạm để xem. Chỉ tính các mũi trong lịch tham khảo có ngày dự kiến không sau hôm nay. Các mũi ngoài lịch và lịch hẹn tự thêm không thay đổi mẫu số hay tử số này; chúng vẫn có trong lịch hẹn/lịch sử riêng. Tab Theo tuổi tự chọn mốc gần tuổi bé nhất không vượt quá tuổi hiện tại, chỉ hiển thị các mũi của một mốc. **Tất cả mốc** mở bảng các mốc và tiến độ, chạm một mốc để thay nội dung, tránh trải danh sách dài.

Thẻ ưu tiên hiển thị một lịch hẹn đã lưu hoặc mũi dự kiến tương lai; mũi cần kiểm tra được truy cập từ số tổng quan, tránh lặp nội dung. Tab **Vắc-xin** nhóm theo tên loại vaccine trong lịch có sẵn, không cộng theo bệnh để tránh đếm trùng vaccine phối hợp. Mỗi dòng có tỷ lệ đã ghi nhận/tổng trong lịch, các chấm theo liều và mũi tiếp theo; vaccine đã hoàn thành vẫn nằm trong danh sách tiến độ, liều đã ghi nhận dùng chấm tròn đặc màu tím. Tỷ lệ là tiến độ bản ghi theo bộ lịch tham khảo hiện có, không xác nhận bé đã hoàn thành phác đồ y tế thực tế (một số liều phụ thuộc loại vaccine).

Chạm nhóm vaccine để xem bệnh phòng ngừa và toàn bộ liều/ngày; chạm liều để xem chi tiết và ghi nhận/sửa. Tab **Đã tiêm** không có ô tìm kiếm; có bộ lọc Vắc-xin cố định, lọc năm và đổi thứ tự mới/cũ. Kết quả nhóm theo ngày và nơi tiêm; buổi đầu mở sẵn, các buổi khác thu gọn. Khi lọc thì các buổi có kết quả mở sẵn; danh sách dựng theo nhu cầu để hỗ trợ nhiều bản ghi. Phản ứng được tóm tắt dưới từng mũi, chi tiết có đầy đủ. Có số kết quả và nút xóa bộ lọc khi không tìm thấy. Lịch hẹn tự lưu được phân biệt với ngày dự kiến và không phải xác nhận đặt hẹn từ cơ sở tiêm. Chữ đồng bộ Tăng trưởng: tên màn hình/tiêu đề vùng gần đen #23332E, đậm 700; số liệu đã ghi nhận xanh lá đậm #194C3C, đậm 700; lựa chọn/trạng thái xanh lá #286B52, đậm 600; thông tin phụ xám xanh #718078. Riêng số liệu/ngày dự kiến dùng tím #655080. Nền thẻ dự kiến tím nhạt, đã tiêm xanh nhạt.

Chi tiết vaccine dùng thẻ tiến độ và từng liều có số thứ tự/dấu hoàn thành, trạng thái và ngày. Chi tiết một mũi có thẻ tên/ngày nổi bật, nhóm phòng bệnh/nơi tiêm và nhóm phản ứng/ghi chú; nút ghi nhận hoặc sửa cố định phía dưới, nội dung cuộn độc lập. Cả hai bảng có nút đóng, nền kem và các thẻ trắng bo góc.

Nút **Thêm** chỉ mở trực tiếp **Thêm vắc-xin bổ sung**. Tên vắc-xin và Phòng bệnh nằm chung một vùng, chỉ nhập một lần. Dùng **Thêm mũi tiêm** để tạo nhiều liều; từng liều tự đặt tên Mũi 1, Mũi 2… theo thứ tự, có ngày, trạng thái Đã tiêm/Dự kiến, nơi tiêm, phản ứng và ghi chú riêng. Thêm liều mới sẽ thu gọn các liều trước; có thể mở lại hoặc bỏ liều chưa lưu. Không có ô nhập tên mũi; khi bỏ mũi ở giữa, các mũi còn lại được đánh số liên tục trước khi lưu. Các liều được kiểm tra toàn bộ trước khi lưu trong một lần, có ID riêng và chung `groupId`. Tab Vắc-xin có nhóm **Vắc-xin bổ sung** hiển thị tiến độ chung, không làm thay đổi mẫu số lịch tham khảo. Liều dự kiến xuất hiện ở lịch hẹn đã lưu, liều đã tiêm xuất hiện trong lịch sử. Sửa từng liều giữ `groupId`; dữ liệu cũ không có `groupId` vẫn đọc được.

Ghi nhận mũi có sẵn bằng cách chạm mũi trong Theo tuổi/Vắc-xin → **Ghi nhận đã tiêm**. Nút lưu cố định phía trên bàn phím; đóng khi có thay đổi và xóa đều có xác nhận. Ngày của liều Đã tiêm không được sau hôm nay; Dự kiến cho phép chọn ngày tương lai. Lưu ngày dự kiến không tạo thông báo hệ điều hành.

Trường `vaccinations` lưu theo ID bé trong SharedPreferences; dữ liệu cũ thiếu trường được coi là rỗng, không suy diễn lịch sử tiêm từ chuỗi tổng quan. Home hiển thị số mũi thực tế đã ghi nhận. Lịch mẫu kế thừa từ `mobile_1`, tính ngày dự kiến theo ngày sinh; cần đối chiếu với cơ sở tiêm chủng trước khi sử dụng thực tế. Nhắc lịch hệ điều hành chưa được triển khai.

Kiểm tra: `flutter test test/vaccination_test.dart test/vaccination_history_test.dart test/home_actions_test.dart test/home_layout_test.dart test/demo_sync_test.dart`.
