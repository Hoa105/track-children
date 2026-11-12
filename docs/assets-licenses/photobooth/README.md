# Nguồn và tình trạng quyền sử dụng asset Photobooth

Danh mục kỹ thuật được tạo từ `mobile/assets/photobooth/` bằng
`mobile/tool/build_photobooth_catalog.py`. Không đổi tên hoặc xóa bản gốc.

- Khung: 10 PNG, Classic / Film / Birthday / Christmas / Halloween. Chưa có
  giấy phép nguồn trong thư mục khung; cần bằng chứng quyền nhúng/phân phối
  trước khi phát hành APK hoặc công khai asset.
- Animals, Cartoon, Rainbow, Christmas: chưa có giấy phép kèm bản nguồn.
  Không coi việc có file trong repo là bằng chứng quyền phân phối.
- Birthday: giữ nguyên LICENSE.txt và README.txt. Điều khoản cho phép thành
  phẩm scrapbook, nhưng hạn chế chia sẻ file số gốc; quyền nhúng bộ file vào
  ứng dụng chưa được xác nhận. Cần làm rõ với chủ sở hữu trước phân phối.
- Halloween: giữ nguyên LICENSE.md. Điều khoản cho phép tích hợp vào dự án
  hoàn chỉnh và hạn chế phân phối gói asset độc lập; cần giữ bằng chứng nguồn
  và kiểm tra hình thức phát hành app cụ thể.

Việc triển khai và build debug nội bộ theo yêu cầu không xác nhận giấy phép
cho bản phân phối. Không tải lên server, public repo hoặc phát hành bộ asset.

Kiểm tra kỹ thuật: Birthday có 11 PNG sticker và 7 JPG (không đưa JPG vào
selector). Animals/bunny.png và muccca.png là RGB, bị loại khỏi selector/bundle
Photobooth vì không có alpha. Chim 64×64 được đánh dấu nguồn độ phân giải thấp.
Penguin 8000×8000 được decode theo kích thước giới hạn, không decode toàn bộ.
