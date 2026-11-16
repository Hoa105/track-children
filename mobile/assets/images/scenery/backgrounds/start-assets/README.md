# Bé lớn khôn – Start Assets v1.0

Bộ tài nguyên tích hợp chính thức từ bước 7. Không dùng ảnh preview làm giao diện.

## Thư mục
- background/: 5 cặp SVG/PNG, tất cả PNG 1080 × 2400.
- mascot/: 4 PNG RGBA 640 × 600.
- decorations/: 9 cặp SVG/PNG.
- manifest.json: thông số điểm neo từng tư thế.
- QA-step7.md: kết quả và giới hạn kiểm tra.
- preview-360x800.png và preview-all-states.png: tham chiếu bố cục.

## Tích hợp
1. Dùng nền #F0F5E7 và start_background.png; hoặc dùng background_base, background_clouds, background_hills riêng. Không chồng hai phương án.
2. Các lớp nền cùng canvas 9:20, áp dụng cùng phép scale/crop. Foreground căn đáy theo cùng hệ tọa độ.
3. Circle phía sau nhân vật; ground_shadow dưới chân; các doodle tùy chọn không che mặt hoặc chữ. Foreground ở lớp trước, tránh che nhân vật.
4. Giữ container mascot tỉ lệ 640:600, điểm neo thân (320,440), tương ứng (0.5,0.733333). Không crop từng ảnh theo alpha bbox; preload đủ 4 trạng thái.
5. Idle → Jump → Welcome → Happy là chuỗi gợi ý. Dịch Y bằng animation, không thay đổi layout. Bỏ qua hoặc rút ngắn animation nếu hệ thống yêu cầu giảm chuyển động; không trì hoãn startup hoặc điều hướng hiện hành.
6. Render tên Bé lớn khôn và slogan Cùng con lớn khôn mỗi ngày bằng Nunito của app, màu #29451E và #477921; không thêm lá trên tên.
7. Ưu tiên SVG nếu framework hỗ trợ; dùng PNG thay thế, không render đồng thời cả hai.

## Green Sprout
#F0F5E7, #FFFFFF, #D9EFA9, #B6E34E, #538B29, #29451E, #EAF5C9, #477921. Giữ màu mascot gốc.

## Nghiệm thu khi tích hợp
Kiểm tra 360 × 800 và các tỉ lệ màn hình khác, safe area, độ tương phản, chuyển đổi tư thế, startup/điều hướng và giảm chuyển động. Không thay đổi API/CSDL/logic khởi động.

## Giới hạn
Mascot được tách từ sheet minh họa nên có sai khác nhẹ về hình dáng giữa tư thế; điểm neo đã được chuẩn hóa theo thân, không theo chân. Preview dùng font thay thế. Chưa kiểm thử runtime ứng dụng.
