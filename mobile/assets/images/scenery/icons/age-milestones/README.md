# Bé lớn khôn – Milestone assets v3

- active/ và inactive/: mỗi thư mục 6 icon PNG RGBA và SVG (canvas 512 × 512, nền trong suốt).
- Cùng hình học giữa hai trạng thái; căn đáy y=479. Không crop hoặc scale từng icon riêng.
- Active: thân #388500, đỉnh và toàn bộ vân #A9EB23. Inactive: thân #B5DF90, đỉnh và toàn bộ vân #D9FA8A.
- Mốc 0–3 tháng có đủ các nét vân như các mốc khác.
- timeline/: connector_up/down (PNG 320×112, SVG 160×56) theo hai trạng thái màu; timeline_alternating (PNG 1200×120, SVG 600×60) cho cả hàng. Không có node tròn.
- Dùng 5 đoạn nối theo thứ tự up, down, up, down, up. Đặt sau icon, ngang hàng gần đáy thân; nếu dùng toàn hàng, kéo ngang theo 6 ô bằng nhau, giữ chiều cao phù hợp.
- Nhãn tuổi là text UI (không nhúng vào icon); ví dụ 22 tháng chọn stage_05 active, các mốc khác inactive.
- preview.png chỉ dùng đối chiếu thiết kế.

SVG được dựng lại theo mẫu để bảo đảm màu và hình học nhất quán, không phải bản cắt pixel nguyên gốc.

V3: vân trên tiếp nối chính xác tại tọa độ (46,44); vân chéo và vân thân gặp nhau tại (79,60). Giữ bảng màu, tên file, canvas, vị trí và timeline như V2.
