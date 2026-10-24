# Bộ dữ liệu test đồng bộ

## Hoạt động

Trang khám phá mới ưu tiên thẻ “Hôm nay chơi gì?” với minh họa nhiều lớp, nền chuyển sắc, nút đổi gợi ý và “Cùng bé chơi”. Gợi ý nổi bật chỉ lấy hoạt động đã có nội dung riêng, sắp theo khoảng tuổi gần bé nhất. Bên dưới có chọn nhanh 5/10/15 phút, tối đa 4 gợi ý theo tuổi, các ô nhóm màu riêng và tối đa 3 trò đã từng thử. Danh sách đã thử chưa phải lịch sử theo ngày. Không đặt tỷ lệ hoàn thành toàn thư viện ở đầu trang.

Thẻ phản hồi nhấn bằng thu nhẹ, trang đầu hiện bằng mờ/trượt, đổi gợi ý dùng AnimatedSwitcher, minh họa nổi bật nối sang chi tiết bằng Hero. Yêu thích có phản hồi co giãn, ghi nhận đổi biểu tượng xác nhận. Các hiệu ứng tùy chỉnh tắt khi hệ thống yêu cầu giảm chuyển động. Minh họa dùng asset khối đồ chơi có sẵn và icon vector nhiều lớp; không thêm phụ thuộc hoặc tải ảnh qua mạng.

Home → Hoạt động mở thư viện 6 nhóm theo ID bé đang chọn. Gồm tổng quan tiến độ, danh sách nhóm, bộ lọc trạng thái/độ tuổi 0–36 tháng/thời lượng và sắp xếp theo tuổi bé hoặc chưa thực hiện trước. Mục có thời lượng “Theo bữa” chỉ xuất hiện khi không lọc thời lượng. Phù hợp tuổi ưu tiên khoảng tuổi chứa tuổi bé, sau đó khoảng gần nhất. Khoảng lọc tuổi lấy các hoạt động có khoảng tuổi giao nhau.

Chi tiết có yêu thích và đánh dấu/bỏ đánh dấu; nút ghi nhận cố định dưới màn hình. Tiến độ lưu trong `completedActivities` theo ID bé, yêu thích trong `favoriteActivities` theo tài khoản. Dữ liệu cũ thiếu trường được coi là rỗng; Home hiển thị số đã thực hiện thực tế. Không tự hoàn thành theo tuổi, không tự tạo nhật ký. Chỉ hồ sơ tài khoản hiện tại được cập nhật; luồng nhận hồ sơ chia sẻ liên tài khoản chưa có trong DemoStore.

Giao diện kế thừa phông ứng dụng, AppColors/AppLayout, nền kem, thẻ trắng bo góc 24; tiêu đề gần đen 700, số ghi nhận xanh đậm 700, trạng thái xanh 600 và thông tin phụ xám xanh. Chưa có phát âm thanh. Có nội dung riêng cho xếp khối, Con cò bé bé, Thỏ con đi chợ; các hoạt động khác ghi rõ hướng dẫn chi tiết đang được bổ sung, không dùng hướng dẫn xếp khối cho mọi loại như bản mẫu.



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

## Phạm vi mô phỏng

Kho test phục vụ đồng bộ trên **một thiết bị**, chưa đồng bộ qua backend hoặc giữa hai máy. Các thao tác gửi email/SMS, chấp nhận lời mời để cấp quyền tài khoản khác, chuyển quyền sở hữu, xóa tài khoản thật, đăng nhập mạng xã hội, nhắc lịch hệ điều hành và khóa sinh trắc chưa được kết nối dịch vụ. Các màn hình xem thử của chúng không xác nhận tính đúng đắn của dịch vụ thật. Tùy chọn sinh trắc hiện chỉ lưu trạng thái mô phỏng.

Lượng sữa trên Home mở công cụ ước tính theo cân nặng (xem bên dưới). Hoạt động mở danh sách nhóm theo bé. Nhật ký mở danh sách và các chức năng ghi chép, chi tiết. Tiêm chủng mở Sổ tiêm chủng riêng. Nút cộng mở bảng thao tác nhanh: “Thêm số đo” đi đến biểu mẫu tăng trưởng; “Viết nhật ký” mở biểu mẫu nhật ký; ghi sữa hiện “Chưa khả dụng”. Thẻ cân nặng/chiều cao mở đúng tab theo dõi; mức thay đổi so với lần đo trước. Chuông thông báo mở trung tâm nhắc lịch trong ứng dụng.

## Thông báo trong ứng dụng

Lấy lịch tiêm dự kiến từ cùng dữ liệu với sổ tiêm, gồm mũi bổ sung đã hẹn. Hiển thị lịch trong 7 ngày tới và lịch đã qua không quá 30 ngày chưa ghi nhận tiêm; không coi thiếu lịch sử là khẳng định bé chưa tiêm. Mũi đã ghi nhận tiêm không còn hiển thị. Lọc Tất cả/Chưa đọc, đọc tất cả và chạm mở sổ tiêm đúng bé. Trạng thái đọc lưu theo tài khoản; ID chứa bé, mũi, ngày hẹn và giai đoạn sắp tới/hôm nay/đã qua để lịch thay đổi có thể nhắc lại. Công tắc Thông báo & nhắc nhở trong Cài đặt tắt/bật danh sách và số chưa đọc trên chuông. Chưa tích hợp push hoặc nhắc lịch hệ điều hành khi ứng dụng đóng.

## Lượng sữa

Màn hình ban đầu hiển thị mức đặt sẵn **60 mL/cữ** (thể tích sữa sau pha, không phải khuyến nghị chung). Bấm **Tính theo cân nặng** mở màn hình nhập riêng cho cân nặng, số cữ và điều kiện áp dụng. Bấm **Tính lượng sữa** với dữ liệu hợp lệ sẽ quay về Lượng sữa và cập nhật thẻ chính bằng mL/cữ, tổng mL/ngày và số cữ. Quay lại khi chưa tính giữ nguyên kết quả trước đó. **Dùng mức mặc định** xóa kết quả tính thử và quay về 60 mL/cữ. Kết quả chỉ giữ trong phiên màn hình hiện tại.

Home → Lượng sữa mở màn hình theo ID bé, điền cân nặng gần nhất có ngày đo. Sửa cân nặng chỉ để tính thử, không lưu số đo. Người dùng xác nhận bé đủ tháng/khỏe mạnh và hoàn toàn bú bình; nhập số cữ (mặc định 8). Kết quả = kg × 150 mL/ngày, chia số cữ, làm tròn hiển thị đến mL; không tính muỗng hoặc nước pha. Sửa đầu vào xóa kết quả cũ.

Phạm vi công cụ: đủ 7 ngày đến dưới 6 tháng, từ 2,5 kg. Trường hợp ngoài phạm vi, sinh non/có bệnh/chưa rõ sức khỏe hoặc bú mẹ trực tiếp không xuất kết quả. Nguồn hệ số: WHO 2021, Infant and young child feeding, trang 51 (https://iris.who.int/handle/10665/346568). Giới hạn tuổi là phạm vi sản phẩm, tham khảo NHS (https://derbyshirefamilyhealthservice.nhs.uk/our-services/0-5-years/infant-feeding-and-nutrition/formula-feeding), không gán cho WHO. Công cụ không kê lượng sữa bắt buộc, không tính sữa bổ sung khi bú mẹ trực tiếp.

Chữ theo Theo dõi: tiêu đề gần đen 700, số nhập xanh đậm 700, số ước tính tím, lựa chọn xanh 600, thông tin phụ xám xanh.

Thông tin đăng nhập được lưu dạng rõ **chỉ trong kho test hư cấu này**, không phải kiến trúc xác thực để dùng thật. Không nhập dữ liệu thật vào bộ test.

## Mọc răng

Home → Mọc răng mở trang theo dõi của bé đang chọn: sơ đồ 20 răng sữa, tiến độ, ngày mọc đầu tiên, danh sách đã mọc và tối đa 3 nhóm răng sắp mọc. Chạm vào răng để ghi nhận/sửa ngày/bỏ đánh dấu (có xác nhận xóa). Ngày mọc nằm trong khoảng ngày sinh đến hôm nay; mỗi vị trí chỉ có một bản ghi. Dữ liệu lưu cục bộ theo ID bé, Home tự cập nhật số đếm.

Dữ liệu cũ thiếu trường `teeth` được coi là rỗng, không suy diễn từ chuỗi tổng quan cũ. Bộ mẫu mới/khôi phục có các răng theo mốc tuổi tham khảo; không tự thêm răng khi bé lớn lên. Nguồn mốc tuổi: https://www.mouthhealthy.org/all-topics-a-z/eruption-charts ; thông tin tham khảo: https://www.mouthhealthy.org/all-topics-a-z/teething . Đây không phải chẩn đoán.



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



## Nhật ký

Nhật ký lưu trong `journalEntries` theo ID bé. Dữ liệu cũ từ `journal` được chuyển tiếp khi đọc; sau mỗi lần lưu/xóa, `journal` được cập nhật bằng bản ghi mới nhất để đồng bộ Trang chủ. Xóa hết sẽ giữ danh sách rỗng. Chỉ hồ sơ thuộc tài khoản hiện tại được truy cập; chưa có luồng nhận hồ sơ chia sẻ liên tài khoản. Danh sách hỗ trợ lọc ngày, thêm, xem, sửa, xóa có xác nhận. Nút Viết nhật ký trong ghi chép nhanh mở biểu mẫu. Ảnh camera/thư viện lưu cục bộ cùng bản ghi; cần kiểm tra quyền trên thiết bị thật.
