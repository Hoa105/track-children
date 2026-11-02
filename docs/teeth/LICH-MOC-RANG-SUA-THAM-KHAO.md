# LỊCH MỌC RĂNG SỮA THAM KHẢO (0–60 THÁNG)

**Ứng dụng:** Bé lớn khôn  
**Mục đích:** Dữ liệu cho sơ đồ hàm răng theo tháng tuổi; không dùng để chẩn đoán chậm mọc răng.

## 1. Nguồn và nguyên tắc

Nguồn chính: American Dental Association (ADA), *Tooth Eruption Charts*: https://www.mouthhealthy.org/all-topics-a-z/eruption-charts

Bảng sử dụng **tháng bắt đầu** của khoảng tuổi mọc tham khảo để đánh dấu một cặp răng là **có thể đã bắt đầu mọc**. Đây là cách ánh xạ phục vụ giao diện, **không phải** số răng trung bình, số răng kỳ vọng hoặc số răng bắt buộc phải có ở tuổi đó. Hai răng đối xứng không nhất thiết mọc cùng lúc.

## 2. Mã 10 cặp răng đối xứng

| Mã | Tên cặp răng | FDI (2 răng) | Khoảng tuổi mọc tham khảo (tháng) | Bắt đầu đánh dấu (tháng) |
|---|---|---|---:|---:|
| 1 | Răng cửa giữa hàm dưới | 71, 81 | 6–10 | 6 |
| 2 | Răng cửa giữa hàm trên | 51, 61 | 8–12 | 8 |
| 3 | Răng cửa bên hàm trên | 52, 62 | 9–13 | 9 |
| 4 | Răng cửa bên hàm dưới | 72, 82 | 10–16 | 10 |
| 5 | Răng hàm thứ nhất hàm trên | 54, 64 | 13–19 | 13 |
| 6 | Răng hàm thứ nhất hàm dưới | 74, 84 | 14–18 | 14 |
| 7 | Răng nanh hàm trên | 53, 63 | 16–22 | 16 |
| 8 | Răng nanh hàm dưới | 73, 83 | 17–23 | 17 |
| 9 | Răng hàm thứ hai hàm dưới | 75, 85 | 23–31 | 23 |
| 10 | Răng hàm thứ hai hàm trên | 55, 65 | 25–33 | 25 |

## 3. Bảng tích lũy theo từng tháng tuổi

**Quy tắc:** Với tháng tuổi `m`, chọn mọi mã có `tháng_bắt_đầu <= m`; số răng có thể đã bắt đầu mọc = `2 × số mã được chọn`.

| Tháng tuổi | Mã các cặp răng có thể đã bắt đầu mọc | Số cặp | Số răng sữa |
|---:|---|---:|---:|
| 0 | — | 0 | 0 |
| 1 | — | 0 | 0 |
| 2 | — | 0 | 0 |
| 3 | — | 0 | 0 |
| 4 | — | 0 | 0 |
| 5 | — | 0 | 0 |
| 6 | 1 | 1 | 2 |
| 7 | 1 | 1 | 2 |
| 8 | 1, 2 | 2 | 4 |
| 9 | 1, 2, 3 | 3 | 6 |
| 10 | 1, 2, 3, 4 | 4 | 8 |
| 11 | 1, 2, 3, 4 | 4 | 8 |
| 12 | 1, 2, 3, 4 | 4 | 8 |
| 13 | 1, 2, 3, 4, 5 | 5 | 10 |
| 14 | 1, 2, 3, 4, 5, 6 | 6 | 12 |
| 15 | 1, 2, 3, 4, 5, 6 | 6 | 12 |
| 16 | 1, 2, 3, 4, 5, 6, 7 | 7 | 14 |
| 17 | 1, 2, 3, 4, 5, 6, 7, 8 | 8 | 16 |
| 18 | 1, 2, 3, 4, 5, 6, 7, 8 | 8 | 16 |
| 19 | 1, 2, 3, 4, 5, 6, 7, 8 | 8 | 16 |
| 20 | 1, 2, 3, 4, 5, 6, 7, 8 | 8 | 16 |
| 21 | 1, 2, 3, 4, 5, 6, 7, 8 | 8 | 16 |
| 22 | 1, 2, 3, 4, 5, 6, 7, 8 | 8 | 16 |
| 23 | 1, 2, 3, 4, 5, 6, 7, 8, 9 | 9 | 18 |
| 24 | 1, 2, 3, 4, 5, 6, 7, 8, 9 | 9 | 18 |
| 25 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 26 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 27 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 28 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 29 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 30 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 31 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 32 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 33 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 34 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 35 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 36 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 37 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 38 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 39 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 40 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 41 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 42 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 43 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 44 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 45 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 46 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 47 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 48 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 49 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 50 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 51 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 52 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 53 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 54 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 55 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 56 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 57 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 58 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 59 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |
| 60 | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 | 10 | 20 |

## 4. Quy tắc hiển thị giao diện

- Câu chính: **“Trẻ có thể mọc được X chiếc răng sữa”**; trong đó X lấy từ cột số răng sữa.
- Ví dụ tháng 10: **“Trẻ có thể mọc được 8 chiếc răng sữa”**, gồm các cặp số **1, 2, 3, 4** (mỗi cặp 2 răng).
- Trên sơ đồ hàm răng, tô màu các vị trí FDI thuộc các mã cặp răng đã đánh dấu; giữ các vị trí này khi tăng tháng tuổi.
- Ghi chú ngay dưới số liệu: *“Đây là số răng có thể đã bắt đầu mọc theo lịch tham khảo; thời điểm mọc thực tế khác nhau ở mỗi trẻ.”*
- Không gọi số này là “số răng chuẩn”, không dùng nó để kết luận chậm mọc răng.
- Trong chức năng theo dõi thực tế, trạng thái **đã mọc** phải dựa trên dữ liệu phụ huynh ghi nhận, không suy ra từ lịch tham khảo.
- Đến 60 tháng, sơ đồ này chỉ thể hiện **20 răng sữa**, không bao gồm răng vĩnh viễn hay quá trình thay răng.

## 5. Tệp dữ liệu kèm theo

`LICH-MOC-RANG-SUA-0-60-THANG.csv`: 61 dòng, có tháng tuổi, danh sách mã cặp, số cặp và số răng sữa có thể đã bắt đầu mọc.
