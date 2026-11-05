# Admin đánh giá phát triển

Hai mục menu:
- **Bộ câu hỏi phát triển**: bộ tuổi → câu hỏi → nội dung / kiểm duyệt và công bố / phiên bản và nhật ký.
- **Lời khuyên phát triển**: 6 biến thể cố định; xem thử kết quả bằng dữ liệu giả lập.

Mọi Admin đang hoạt động có cùng quyền. Không có workflow phân vai hoặc cấm tự duyệt. Backend vẫn kiểm tra phiên bản và nội dung. Mỗi phê duyệt cần căn cứ; nhập seed không tạo phê duyệt.

## Thiết lập local

Chạy từ thư mục gốc, với `DATABASE_URL` trong môi trường hoặc cấu hình backend:

```powershell
.venv/Scripts/python.exe backend/scripts/development_admin_setup.py --apply --seed
```

Lệnh chỉ áp dụng migration **024** nếu chưa có và nhập đúng văn bản từ bộ tài liệu: 159 câu/kỹ năng, 6 lời khuyên. Yêu cầu schema 021–023 đã được áp dụng. Nội dung mới chưa công bố và đang tắt; giữ nguyên 6 câu mẫu cũ. Không sửa câu trả lời hay kết quả của trẻ. Nhập lại hiển thị diff và không đụng revision công bố. Nếu dữ liệu đã được sắp xếp hoặc sửa metadata, preview có thể yêu cầu xử lý xung đột trước khi nhập.

## Luồng sử dụng

1. Tạo câu hoặc xem trước rồi nhập CSV/JSON/bộ CDC đính kèm.
2. Bổ sung câu hỏi, hướng dẫn, tên kỹ năng, hai nhận xét, cách quan sát, văn bản đọc và nguồn. Media là tùy chọn, nhưng có media phải có mô tả và attribution trước công bố.
3. Lưu bản nháp mới. Bản đang công bố giữ nguyên. Không đổi lĩnh vực câu từng công bố; tạo câu mới nếu cần đổi.
4. Duyệt bốn hạng mục trên đúng revision, nhập căn cứ phê duyệt. Quyết định mới nhất có hiệu lực.
5. Công bố từng nội dung hoặc toàn bộ câu chưa xóa trong bộ. Công bố không tự bật sử dụng.
6. Công bố và bật 6 mẫu lời khuyên; bật các câu cần dùng; sau đó bật bộ. Backend chặn bộ trống hoặc chưa đủ nội dung công bố.
7. Tắt hoặc xóa mềm chỉ ảnh hưởng các lần đánh giá mới. Khôi phục luôn ở trạng thái tắt, giữ revision công bố. Xóa bộ không xóa từng câu.

`Đang bật` chỉ diễn tả trạng thái sử dụng, không thay thế phê duyệt chuyên môn hoặc kiểm chứng runtime. Toàn bộ dữ liệu tài liệu hiện là DRAFT; không sử dụng nút duyệt như cách giả lập medical sign-off trong CSDL thật.

## Nhập/xuất

CSV UTF-8 và JSON sử dụng cùng cấu trúc export. `payload` và `source_refs` là JSON trong mỗi ô CSV. Preview không ghi dữ liệu, có diff trước/sau và lỗi theo dòng. Commit kiểm tra fingerprint CSDL và thực hiện toàn bộ tệp trong một transaction. Tệp tối đa 500 dòng / 5 MB trên giao diện. Import không thay stable code, bộ tuổi, thứ tự hoặc lĩnh vực của nội dung đã tồn tại; các thay đổi đó được xử lý tại trang quản lý.

Bộ CDC đóng gói nằm tại `backend/app/features/development/data/cdc-draft.json`; được ghép từ question bank và skill/advice seed của tài liệu. Không viết lại văn bản chuyên môn. Những media còn thiếu alt trong tài liệu vẫn được lưu nháp, nhưng sẽ bị chặn công bố cho đến khi bổ sung và duyệt.

## Kiểm thử

```powershell
cd admin-web
npm run build
npm test
```

```powershell
.venv/Scripts/python.exe backend/tests/run_development_admin_tests.py
```

Script backend tạo một CSDL trống `development_admin_test_<uuid>` trên PostgreSQL local, áp dụng schema development với các bảng định danh tối thiểu, chạy test rồi xóa đúng CSDL thử. Không sao chép dữ liệu người dùng và không ghi vào CSDL ứng dụng. Các test bao gồm import idempotent, preview lỗi thời, review mới nhất, publication pointer, xung đột revision, khôi phục tắt, sắp xếp, API serialization và kết quả sandbox từ Rule Engine/resolver/presenter tham chiếu. Không thay thế kiểm thử toàn bộ auth/migration chain hoặc Android/iOS.

## Giới hạn

- Thay đổi này là phân hệ Admin; không triển khai luồng đánh giá phụ huynh/mobile mới.
- TTS dùng giọng của trình duyệt/thiết bị, có thông báo nếu không hỗ trợ.
- Preview media không xác nhận bản quyền hoặc playback trên mọi thiết bị; iframe bị chặn vẫn có hướng dẫn văn bản.
- Ứng dụng dùng hash router; cảnh báo rời trang có thay đổi chưa lưu và kiểm tra revision khi lưu.

## Cập nhật luồng giao diện

Mục **Bộ câu hỏi** dùng cùng cách trình bày với **Hoạt động & nhóm**:
- Tab **Bộ câu hỏi**: tìm/lọc, mở bộ, bật bộ, tắt bộ và xóa mềm ngay ở danh sách.
- Tab **Kiểm duyệt & công bố**: hàng chờ chung, mở đúng câu để đọc và duyệt; không còn mục Review & publish riêng.
- Chi tiết bộ có các tab **Câu hỏi**, **Kiểm duyệt & công bố**, **Nhật ký**. Nút bật/tắt bộ luôn ở đầu trang.
- Mỗi dòng câu có **Xem câu hỏi**, **Chỉnh sửa**, **Bật câu**, **Tắt câu**. Hai nút bật/tắt đều hiển thị; nút không phù hợp trạng thái hiện tại bị vô hiệu hóa.
- Chi tiết câu mở mặc định ở **Chi tiết câu hỏi**, hiển thị câu, hướng dẫn, ba lựa chọn và ảnh hoặc iframe YouTube. Chỉnh sửa là tab riêng, không thay thế trang xem chi tiết.
- Các liên kết cũ `/development/content/:id/edit` và `/development/review` vẫn mở trong cùng khu vực Bộ câu hỏi.

Hàng chờ API dùng `AdminReviewRow` để trả các trường camelCase đúng với giao diện. Kiểm thử DOM mới mount cả `App` và router thật, chỉ giả lập auth/API: bật–tắt bộ/câu, từ danh sách đến chi tiết, ba đáp án, ảnh, video, tab duyệt và liên kết cũ. Đây không phải kiểm thử hình ảnh hoặc playback video trên thiết bị.

## Danh sách bộ câu hỏi sau rà soát

- Bảng chính có bốn cột: Bộ câu hỏi, Số câu, Trên app, Thao tác.
- Tên bộ theo mốc tuổi, kèm nguồn để phân biệt bộ CDC và bộ tự biên soạn. Chỉ hiện phiên bản khi cùng tuổi và nguồn có nhiều bộ. Không hiển thị mã kỹ thuật, trạng thái công bố hoặc số câu đã công bố trong bảng này.
- Lọc theo mốc tuổi và Hiển thị / Đã ẩn. Bộ đã xóa nằm trong khu vực riêng, không trộn với trạng thái hiển thị.
- Thao tác thường dùng: Xem bộ, Hiển thị hoặc Ẩn. Xóa bộ nằm trong menu Thêm; khôi phục chỉ có trong khu vực Đã xóa và giữ bộ ở trạng thái ẩn.
- Chỉnh sửa thông tin bộ chuyển vào trang chi tiết. Mã và phiên bản được tự cấp khi tạo mới.
- Kiểm duyệt/công bố và nhập/xuất có tab riêng trong cùng mục Bộ câu hỏi.
- Trạng thái hiển thị dựa trên cấu hình bộ, việc đã công bố và số câu đang được phép dùng. API cung cấp `visibleQuestionCount`, không suy từ tổng số câu đã công bố.
- Không có migration CSDL mới. Không thay đổi trạng thái hoặc nội dung các bộ đang có.

## Bộ câu hỏi: trạng thái và xuất bản

Danh sách có cột Bộ câu hỏi, Số câu, Trạng thái, Ngày cập nhật, Thao tác. Bộ lọc trạng thái dùng dropdown: Tất cả / Ẩn / Xuất bản / Đã xóa / Nháp. Bộ chưa từng công bố (kể cả đang chờ duyệt) là Nháp; bộ từng công bố nhưng không hiển thị là Ẩn; xóa mềm được ưu tiên hiển thị Đã xóa. Không đổi enum lưu trữ hoặc làm mất các phiên bản cũ.

Cột thao tác chỉ có Ẩn hoặc Xuất bản. Bộ đã xóa không có thao tác tại danh sách; khôi phục trong chi tiết. Bấm tên bộ hoặc dòng để mở câu hỏi. Ngày cập nhật lấy thay đổi mới nhất của bộ và các câu thuộc bộ, hiển thị theo múi giờ Việt Nam.

Xuất bản từ danh sách gọi endpoint `/admin/development/question-sets/{id}/release`: kiểm tra nội dung và 6 lời khuyên, công bố nội dung, bật các câu được công bố lần đầu và cho phép bộ xuất hiện trên app trong cùng một transaction. Câu đã công bố nhưng bị ẩn từ trước vẫn giữ trạng thái ẩn. Bất kỳ lỗi nào đều rollback, không để bộ xuất bản dở dang. Không tự tạo phê duyệt. Các điều kiện chuyên môn và kiểm duyệt vẫn được giữ nguyên.

Nhập/xuất không còn là tab ở danh sách bộ; mở trong tab Câu hỏi của bộ đã chọn. Không có migration hoặc cập nhật hàng loạt dữ liệu thật trong thay đổi này.

## Nhập/xuất tại danh sách bộ câu hỏi

Nhóm thao tác ở đầu bảng gồm Tải mẫu nhập, Nhập tệp, Xuất tệp; Thêm bộ là thao tác tạo mới riêng. Không còn nhập/xuất ở trang danh sách câu hỏi trong bộ.

- Tải mẫu nhập: chọn CSV hoặc JSON; mẫu tải từ API `/admin/development/import/template?kind=skill`, gồm một câu minh họa dựa trên nội dung nguồn đã có, mã BLK và bộ mẫu riêng. Mẫu khớp cấu trúc bộ nhập, không có phê duyệt hoặc trạng thái xuất bản giả.
- Nhập tệp: chọn CSV/JSON → xem trước, lỗi từng dòng và diff → xác nhận nhập bản nháp. Có hướng dẫn cấu trúc và giới hạn tệp. Dữ liệu CDC đính kèm được đặt trong phần mở rộng, không trộn với lựa chọn tệp.
- Xuất tệp: chọn tất cả bộ chưa xóa hoặc các bộ đang lọc, rồi chọn CSV/JSON. Chỉ xuất câu hỏi/kỹ năng, không trộn lời khuyên. Các bộ/câu xóa mềm bị loại khỏi tệp. Không xuất câu trả lời của trẻ.
- Bảng có cột Mốc tuổi riêng. Tên bộ dùng nguồn nội dung; phiên bản chỉ hiện khi cần phân biệt các bộ cùng tuổi và nguồn.

Kiểm thử bổ sung bao gồm tải hai định dạng mẫu, chọn phạm vi xuất từ bộ lọc, mẫu qua validator backend, xuất đúng bộ và loại trừ dữ liệu xóa mềm. Không tự nhập mẫu vào CSDL ứng dụng.

## Đồng bộ tên bộ và hộp thoại nhập/xuất

Tên bộ trong danh sách dùng mốc tuổi (ví dụ 12 tháng); cột thứ hai là Phiên bản. Tuổi vẫn dùng trong bộ lọc và liên kết mở bộ, không thay dữ liệu lưu trữ.

Các hộp thoại tải mẫu, nhập tệp, xuất tệp và kiểm tra dữ liệu dùng chung khung: nhãn Bộ câu hỏi, tiêu đề, vùng nội dung cuộn và thanh thao tác cuối hộp thoại. CSV/JSON dùng hai ô chọn có mô tả; tải mẫu có nút tải chính và thông báo tải thành công. Nhập tệp có vùng chọn file, tên file và tiến trình Chọn tệp → Kiểm tra → Nhập nháp. Phần xem trước có các số lượng nội dung mới, bản sửa, không đổi và lỗi. Màu nền trắng, viền nhẹ, xanh lá và các nút dùng cùng giao diện Admin. Bố cục co về một cột trên màn hình nhỏ.

Chỉ thay giao diện; giữ nguyên cấu trúc tệp, API và điều kiện nhập/xuất.

Sửa tại danh sách: link Sửa mở `QuestionSetEditModal` ngay trên danh sách, không điều hướng sang chi tiết. Lưu thành công tải lại các dòng; URL, bộ lọc và tab hiện tại được giữ nguyên. Trang chi tiết dùng lại cùng form sửa, tránh hai phiên bản form khác nhau. Kiểm thử xác nhận mở/đóng, lưu nội dung và giữ nguyên bộ lọc/đường dẫn.

## Chuẩn hóa câu hỏi — 06/11/2026
- Trạng thái câu hỏi: Nháp (chưa có bản xuất bản), Xuất bản (đã xuất bản và cho phép hiển thị), Ẩn (đã xuất bản nhưng ngừng hiển thị), Đã xóa (xóa mềm).
- Trạng thái câu độc lập với trạng thái bộ; câu chỉ lên app khi bộ cũng xuất bản. Bản sửa chưa xuất bản không thay thế bản đang dùng.
- Bảng câu hỏi dùng một cột Trạng thái, thêm Phiên bản và Ngày cập nhật; lọc đủ bốn trạng thái. Sắp xếp có chế độ riêng.
- Chi tiết dùng PageHeading đồng bộ với danh sách bộ, giữ nội dung, ba đáp án và media; thông tin trạng thái/phiên bản/ngày cập nhật/nguồn tách rõ.
- Nút quay lại dùng dấu <. Xuất bản câu dùng POST /admin/development/content/{id}/release để kiểm tra phiên bản, phê duyệt, xóa mềm và cập nhật bản xuất bản + hiển thị trong cùng giao dịch.

## Bỏ kiểm duyệt câu hỏi — 06/11/2026
- Theo yêu cầu mới: bỏ giao diện Kiểm duyệt & công bố ở bộ câu hỏi và câu hỏi. Nút Duyệt trong bảng chuyển thành Chi tiết; liên kết review cũ mở lại trang chi tiết/danh sách.
- Xuất bản câu hỏi/bộ câu hỏi không yêu cầu các phê duyệt của câu hỏi; tiếp tục kiểm tra nội dung, lĩnh vực, nguồn và media hợp lệ, phiên bản hiện tại, trạng thái xóa và các điều kiện sẵn sàng của bộ. Không tạo phê duyệt giả hoặc sửa dữ liệu đã lưu.
- Lịch sử câu hỏi dùng cùng AuditPanel đầy đủ như bộ câu hỏi; so sánh và nạp bản cũ nằm riêng ở tab Phiên bản. Quy trình lời khuyên giữ nguyên.

## Hoàn thiện thêm câu hỏi — 06/11/2026
- Form Thêm câu hỏi có cùng nhóm nội dung với chỉnh sửa: câu hỏi/hướng dẫn/an toàn, ba đáp án cố định, nhận xét kỹ năng/văn bản đọc, media và nguồn.
- Mã BLK theo tuổi tự sinh, chỉ đọc; thứ tự tự động cuối bộ. Chọn rõ một trong 5 lĩnh vực, kiểm tra nội dung tối thiểu, nguồn trống, mã trùng và giới hạn thứ tự. Lưu tạo Nháp, chưa hiển thị; phần cần hoàn thiện trước xuất bản được ghi rõ.
- Có xác nhận khi đóng form có thay đổi, khóa thao tác khi đang lưu, giữ dữ liệu khi lỗi; tạo xong mở trang chỉnh sửa câu mới.
- Các thao tác câu hỏi xếp trên một hàng trong cột cố định bên phải.

## Chuẩn hóa lời khuyên phát triển — 06/11/2026
- Trạng thái thống nhất với câu hỏi: Nháp / Xuất bản / Ẩn / Đã xóa. Xuất bản cập nhật phiên bản và cho phép hiển thị trong một giao dịch, chỉ yêu cầu dữ liệu hợp lệ; không cần kiểm duyệt thủ công.
- Sáu mẫu có điều kiện/hành động cố định: bỏ thao tác tạo/xóa và nhập/xuất tệp khỏi giao diện. Dữ liệu từng xóa vẫn lọc được và có thể khôi phục về trạng thái không hiển thị.
- Danh sách: tiêu đề, điều kiện áp dụng, phiên bản, trạng thái, ngày cập nhật; lọc dropdown và tìm nội dung; thao tác Sửa / Ẩn / xuất bản, cho phép xuất bản riêng bản nháp mới khi bản cũ đang hiển thị.
- Chi tiết/Chỉnh sửa/Lịch sử dùng cùng bố cục và kiểu chữ với câu hỏi. Giữ chức năng thử kết quả bằng dữ liệu giả lập, không tạo đánh giá thật. Điều kiện lựa chọn và hành động cố định được giữ nguyên khi sửa.

## Gộp mục Bộ câu hỏi & Lời khuyên — 06/11/2026
- Menu chuyên môn chỉ còn một mục Bộ câu hỏi & Lời khuyên tại /development.
- Hai tab Bộ câu hỏi (/development) và Lời khuyên (/development/advice); trang chi tiết lời khuyên dùng /development/advice/{id}. Nút quay lại mở đúng tab.
- Đường dẫn /development-advice và các liên kết chi tiết cũ vẫn mở được trong mục chung; không còn mục menu lời khuyên riêng.
