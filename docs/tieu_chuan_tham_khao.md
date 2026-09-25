# Tài liệu tham khảo: Tiêu chuẩn xây dựng & đánh giá tăng trưởng trẻ em

Tổng hợp phục vụ xây dựng tính năng tiêu chuẩn tăng trưởng, sàng lọc phát triển và tiêm chủng/dinh dưỡng trong app track_children.

## 1. WHO Child Growth Standards (0–5 tuổi)

Bộ chuẩn tăng trưởng thể chất quốc tế do WHO công bố năm 2006, xây dựng từ dữ liệu theo dõi trẻ khỏe mạnh, bú mẹ ở 6 quốc gia. Dùng để đánh giá xem một trẻ cụ thể có đang tăng trưởng bình thường so với chuẩn hay không (0–60 tháng tuổi), tách riêng cho bé trai/bé gái.

### 1.1. Các chỉ số (indicators)

| Chỉ số | Ý nghĩa | Độ tuổi áp dụng |
|---|---|---|
| Weight-for-age (Cân nặng theo tuổi) | Phát hiện **nhẹ cân** (underweight) | 0–60 tháng |
| Length/Height-for-age (Chiều dài/cao theo tuổi) | Phát hiện **thấp còi** (stunting) — đo nằm (length) dưới 24 tháng, đo đứng (height) từ 24 tháng | 0–60 tháng |
| Weight-for-length/height (Cân nặng theo chiều dài/cao) | Phát hiện **gầy còm/suy dinh dưỡng cấp** (wasting) hoặc thừa cân | 0–60 tháng |
| BMI-for-age | Đánh giá thừa cân/béo phì, thay thế weight-for-height ở trẻ lớn | 0–60 tháng (mở rộng 0–19 tuổi ở bộ "Growth Reference 5-19") |
| Head circumference-for-age (Vòng đầu theo tuổi) | Phát hiện bất thường phát triển não (đầu nhỏ/to bất thường) | 0–60 tháng |
| Arm circumference-for-age (Vòng cánh tay) | Sàng lọc nhanh suy dinh dưỡng cấp tại cộng đồng | 3–60 tháng |

### 1.2. Cách tính: hệ số LMS và Z-score

Dữ liệu gốc WHO công bố dưới dạng bảng hệ số **L, M, S** theo từng tháng tuổi (hoặc theo chiều dài/cao), tách theo giới tính:

- **L** — hệ số biến đổi Box-Cox (độ lệch/skewness)
- **M** — giá trị trung vị (median) tại độ tuổi đó
- **S** — hệ số biến thiên (coefficient of variation)

Công thức tính Z-score cho một giá trị đo được:

```
Z = ((value / M)^L - 1) / (L * S)      nếu L ≠ 0
Z = ln(value / M) / S                   nếu L = 0
```

Từ Z-score, suy ra percentile theo phân phối chuẩn (ví dụ Z = 0 → percentile 50; Z = -2 → khoảng percentile 2.3).

### 1.3. Ngưỡng phân loại (WHO/UNICEF)

| Z-score | Weight-for-age | Height-for-age | Weight-for-height / BMI |
|---|---|---|---|
| < -3 | Nhẹ cân nặng (severe) | Thấp còi nặng (severe stunting) | Gầy còm nặng (severe wasting) |
| -3 đến < -2 | Nhẹ cân (moderate) | Thấp còi (stunting) | Gầy còm (wasting) |
| -2 đến +2 | Bình thường | Bình thường | Bình thường |
| > +2 | — | — | Thừa cân (overweight) |
| > +3 | — | — | Béo phì (obese) |

### 1.4. Áp dụng vào app

Tải bảng LMS (.xlsx/.csv, có sẵn theo từng chỉ số và giới tính trên trang WHO) → nhúng dưới dạng dữ liệu tĩnh trong app → viết hàm Dart tính Z-score/percentile theo công thức trên, thay cho percentile hard-code hiện tại trong `growth_service.dart`.

## 2. ASQ-3 (Ages & Stages Questionnaires, bản 3)

Bộ công cụ sàng lọc phát triển do cha mẹ/người chăm sóc tự điền, dùng để phát hiện sớm trẻ có nguy cơ chậm phát triển, cần đánh giá chuyên sâu.

### 2.1. Cấu trúc

- Áp dụng cho trẻ **1 tháng – 5,5 tuổi** (66 tháng), gồm **21 bộ câu hỏi** theo mốc tuổi cụ thể: 2, 4, 6, 8, 9, 10, 12, 14, 16, 18, 20, 22, 24, 27, 30, 33, 36, 42, 48, 54, 60 tháng.
- Mỗi bộ gồm **30 câu hỏi**, chia đều cho **5 lĩnh vực** (6 câu/lĩnh vực):
  1. Giao tiếp (Communication)
  2. Vận động thô (Gross Motor)
  3. Vận động tinh (Fine Motor)
  4. Giải quyết vấn đề (Problem Solving)
  5. Cá nhân – xã hội (Personal-Social)
- Mỗi câu trả lời theo 3 mức: **Có** (10 điểm) / **Đôi khi** (5 điểm) / **Chưa** (0 điểm).
- Có thêm mục "Tổng quan" (Overall) — câu hỏi mở để cha mẹ nêu lo ngại (thị giác, thính giác, hành vi...).

### 2.2. Cách chấm điểm

- Cộng điểm từng lĩnh vực (tối đa 60 điểm/lĩnh vực).
- So với **điểm ngưỡng (cutoff)** riêng cho từng lĩnh vực/mốc tuổi (thường tương đương khoảng -2 SD so với điểm trung bình mẫu chuẩn hóa):
  - **Trên ngưỡng**: phát triển đúng hướng (on schedule)
  - **Vùng theo dõi** (gần ngưỡng, thường trong khoảng 1 SD): cần theo dõi thêm, có thể làm lại sau vài tuần
  - **Dưới ngưỡng**: nên giới thiệu đánh giá chuyên sâu (referral)

### 2.3. Lưu ý bản quyền

ASQ-3 là công cụ thương mại của **Brookes Publishing**. Bảng câu hỏi đầy đủ theo từng mốc tuổi, điểm cutoff chính thức và tài liệu hướng dẫn chấm điểm **phải mua license** để sử dụng hợp pháp trong sản phẩm phát hành/thương mại. App chỉ nên dùng khung cấu trúc (5 lĩnh vực, 21 mốc tuổi, thang điểm 0/5/10) để dựng UI/form; nội dung câu hỏi cụ thể nên tự soạn mới hoặc mua bản quyền chính thức từ agesandstages.com.

## 3. Bộ Y tế Việt Nam — Tiêm chủng & Dinh dưỡng

### 3.1. Lịch tiêm chủng mở rộng (Chương trình TCMR quốc gia, miễn phí)

| Mốc tuổi | Vaccine / mũi tiêm |
|---|---|
| Sơ sinh (24h đầu) | BCG (phòng lao); Viêm gan B (liều sơ sinh) |
| 2 tháng | Vaccine 5 trong 1 (bạch hầu – ho gà – uốn ván – viêm gan B – Hib) mũi 1; Bại liệt (OPV/IPV) mũi 1; Rotavirus liều 1 |
| 3 tháng | Vaccine 5 trong 1 mũi 2; Bại liệt mũi 2; Rotavirus liều 2 |
| 4 tháng | Vaccine 5 trong 1 mũi 3; Bại liệt mũi 3; Rotavirus liều 3 (nếu dùng loại 3 liều) |
| 9 tháng | Sởi mũi 1 |
| 18 tháng | Bạch hầu – ho gà – uốn ván (nhắc lại); Sởi – Rubella (MR) nhắc lại |
| Theo lịch địa phương | Viêm não Nhật Bản B (3 mũi, từ 12 tháng); một số vaccine bổ sung theo chương trình từng tỉnh/thành |

> Ghi chú: lịch trên là khung chương trình tiêm chủng mở rộng (miễn phí); lịch chi tiết có thể thay đổi theo hướng dẫn cập nhật của Bộ Y tế/Viện Vệ sinh dịch tễ theo từng thời kỳ — nên đối chiếu văn bản chính thức mới nhất trước khi đưa vào app.

### 3.2. Khám sàng lọc trước tiêm chủng

Theo **Quyết định 1575/QĐ-BYT (27/03/2023)**: quy định quy trình khám sàng lọc (hỏi tiền sử, đo thân nhiệt, khám toàn trạng...) trước mỗi mũi tiêm để phát hiện chống chỉ định/hoãn tiêm, áp dụng tại cả cơ sở tiêm chủng trong và ngoài bệnh viện.

### 3.3. Dinh dưỡng — ăn bổ sung (ăn dặm)

Theo hướng dẫn của Viện Dinh dưỡng Quốc gia:
- Bắt đầu ăn bổ sung từ **tròn 6 tháng tuổi**, song song duy trì bú mẹ đến 24 tháng hoặc lâu hơn.
- Cho ăn thêm bữa phụ 1–2 lần/ngày giữa các bữa chính, ưu tiên thực phẩm giàu dinh dưỡng, dễ chế biến (trái cây, củ, bánh, sữa/chế phẩm từ sữa).
- Tăng dần độ thô và đa dạng thực phẩm theo tháng tuổi (đảm bảo đủ 4 nhóm: bột đường, đạm, béo, vitamin-khoáng chất).

---

## Nguồn gốc tài liệu

**WHO Child Growth Standards**
- https://www.who.int/toolkits/child-growth-standards
- https://www.who.int/tools/child-growth-standards/standards/weight-for-age
- https://docs.ropensci.org/gigs/reference/who_gs_coeffs.html
- https://www.cdc.gov/growthcharts/who-growth-charts.htm

**ASQ-3**
- https://agesandstages.com/products-pricing/asq3/
- https://support.agesandstages.com/kb/article/210-what-age-range-does-asq3-cover/

**Bộ Y tế Việt Nam**
- https://hcdc.vn/lich-tiem-chung-mo-rong-cho-tre-em-0yWj3L.html
- https://vnvc.vn/lich-tiem-chung-cho-tre-tu-0-den-5-tuoi/
- https://thuvienphapluat.vn/van-ban/The-thao-Y-te/Quyet-dinh-1575-QD-BYT-2023-Huong-dan-kham-sang-loc-truoc-tiem-chung-tre-em-560859.aspx
- https://viendinhduong.vn/storage/app/uploads/public/2026/07/18/quyet_dinh_hd_an_bo_sung.pdf
