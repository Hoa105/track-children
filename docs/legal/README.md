# Nội dung pháp lý phục vụ UI

Đầu mối do chủ dự án cung cấp: đội ngũ Bé Lớn Khôn — belonkhon@gmail.com.

Ba bản tiếng Việt là nguồn nội dung cho `backend/legal-documents.local.json`, version `trial-1.0`. File local chỉ dành cho thử nghiệm, không tự triển khai sang production. Đọc chính sách không đồng nghĩa đã chọn checkbox consent.

App đọc qua API `/api/v1/legal-documents?context=registration`, không hardcode nội dung vào Flutter. Backend local cần đặt `LEGAL_DOCUMENTS_PATH` tới đường dẫn tuyệt đối của `backend/legal-documents.local.json` trong môi trường chạy; với Docker là đường dẫn file bên trong container được mount phù hợp. Chưa cấu hình thì UI báo không tải được tài liệu; không fallback sang chính sách giả. Đợt sửa nội dung này không tự thay đổi `.env` hoặc cấu hình triển khai.

Trước phát hành cần đối chiếu: tên/chủ thể pháp lý đầy đủ và địa chỉ liên hệ cần công bố; danh sách nhà cung cấp/nơi xử lý; luồng AI thực tế; căn cứ xử lý từng mục đích; thời hạn lưu/xóa từng nhóm và backup; SLA quyền dữ liệu; cơ chế ghi nhận đồng ý; xử lý hồ sơ dùng chung và sự cố. Không tuyên bố các nội dung mục tiêu trong chính sách thử nghiệm đã được code thực thi.

Nguồn rà soát ngày 18/11/2026:

- [Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15](https://vanban.chinhphu.vn/?docid=214590&pageid=27160).
- [Nghị định 356/2025/NĐ-CP](https://chinhphu.vn/?docid=216387&pageid=27160).

Đây là bản biên tập phục vụ triển khai, chưa phải kết luận tuân thủ toàn hệ thống. Giữ `effectiveAt` local là thời điểm hợp lệ để đọc trong môi trường test, không diễn giải thành ngày có hiệu lực chính sách production.

Nội dung hiển thị dùng nhãn “Phiên bản thử nghiệm 1.0”, cập nhật ngày 19/11/2026; không dùng nhãn dự thảo. Mã `trial-1.0` là phiên bản đối chiếu đồng ý mới, không ghi đè bằng chứng đồng ý cũ. Thay đổi chỉ xuất lại file chính sách thử nghiệm, không triển khai hoặc thay đổi DB.
