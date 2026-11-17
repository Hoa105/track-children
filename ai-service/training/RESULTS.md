# Kết quả train `kdst_v1`

- Train bằng CPU, 35 epoch, tổng khoảng 3 giờ. Checkpoint tốt nhất ở epoch 35 (macro-F1 trên val 0,557).
- Model ONNX nặng 2,1 MB. Sai lệch giữa ONNX và PyTorch tối đa 1,4e-6.
- Mức điểm: 0 = chưa làm được (Bad), 1 = làm được nhưng loạng choạng (Good), 2 = làm vững (Perfect).
- Baseline: luôn đoán mức phổ biến nhất của bài đó trong tập train.

## Tổng quan trên tập test (60 trẻ chưa từng thấy, 3.051 lần thử)

| Chỉ số | Model | Baseline |
|---|---|---|
| Độ chính xác chấm mức | **70,4%** | 57,3% |
| Macro-F1 chấm mức | **0,572** | 0,234 |
| Nhận diện đúng bài (1 trong 12) | **83,7%** | — |

Độ chính xác theo góc quay: chính diện 72,1%, nghiêng phải 70,0%, nghiêng trái 69,2%.

## Theo từng bài (test)

Ma trận nhầm lẫn: mỗi hàng là nhãn thật, mỗi cột là mức model dự đoán, theo thứ tự 0 / 1 / 2.

| Mã | Bài | n | Độ chính xác | Macro-F1 | Baseline (acc / F1) | Ma trận nhầm lẫn |
|---|---|---|---|---|---|---|
| A01 | Đi lên cầu thang | 269 | 81,0% | 0,567 | 80,7% / 0,298 | [10,4,5] [11,11,11] [7,13,197] |
| A02 | Đi xuống cầu thang | 272 | 79,4% | 0,565 | 80,1% / 0,297 | [11,8,11] [2,10,12] [3,20,195] |
| A03 | Ném bóng qua đầu | 284 | 72,9% | 0,643 | 71,8% / 0,279 | [17,3,0] [8,27,25] [6,35,163] |
| A04 | Đứng một chân 1 giây | 288 | 60,4% | 0,589 | 18,8% / 0,105 | [34,16,4] [9,100,8] [12,65,40] |
| B01 | Đứng một chân trên 3 giây | 207 | 72,9% | **0,722** | 29,0% / 0,150 | [26,10,0] [11,77,23] [2,10,48] |
| B02 | Nhảy lò cò 2–3 bước | 177 | 71,8% | 0,682 | 47,5% / 0,215 | [62,20,2] [5,18,4] [10,9,47] |
| B03 | Bật xa bằng hai chân | 174 | 69,5% | 0,599 | 67,2% / 0,268 | [16,10,4] [6,16,5] [9,19,89] |
| B04 | Bắt bóng | 183 | 52,5% | 0,475 | 32,8% / 0,165 | [38,17,5] [15,8,16] [18,16,50] |
| C01 | Chặn bóng lăn bằng chân | 316 | 70,3% | 0,580 | 63,9% / 0,260 | [15,8,10] [11,36,34] [13,18,171] |
| C02 | Đập bóng nảy | 310 | 65,2% | **0,404** | 69,4% / 0,273 | [5,5,11] [12,12,50] [25,5,185] |
| C03 | Nhảy qua dây | 306 | 83,0% | **0,413** | 83,3% / 0,303 | [0,1,2] [1,12,35] [2,11,242] |
| C04 | Nhảy dây | 265 | 60,8% | 0,618 | 42,6% / 0,199 | [73,28,12] [42,48,9] [6,7,40] |

Nhận xét:
- **Tốt nhất là các bài thăng bằng và nhảy** (B01, B02, A04, C04). Những bài này khác nhau rõ ở tư thế cơ thể, và model hơn baseline rất xa.
- **Yếu nhất là các bài có bóng** (C02, B04). Khung xương không chứa quả bóng, nên model không biết bé đập hay bắt bóng trúng hay trượt.
- **C03 gần như không có mẫu "chưa làm được"** (chỉ 3 mẫu). Độ chính xác cao chủ yếu do đoán "làm vững".
- Ở các bài nhiều mẫu "làm vững" (A01, A02, C03), model chỉ ngang baseline về độ chính xác, nhưng phân biệt được mức thấp tốt hơn (macro-F1 cao gấp đôi).

## Ngưỡng tin cậy (test)

Chỉ trả kết quả khi xác suất của mức dự đoán đạt ngưỡng. Dưới ngưỡng thì báo "chưa chắc chắn" hoặc chuyển sang nhánh LLM.

| Ngưỡng | Tỉ lệ video được chấm | Độ chính xác trên phần được chấm |
|---|---|---|
| 0 | 100% | 70,4% |
| 0,5 | 89,4% | 73,1% |
| 0,6 | 74,2% | 77,4% |
| **0,7** | **59,9%** | **81,5%** |
| 0,8 | 44,0% | 87,0% |
| 0,9 | 19,9% | 90,6% |

Đề xuất dùng **0,7**. Mức này chấm được khoảng 60% video với độ chính xác khoảng 81,5%. Giá trị này đã được ghi vào `min_confidence` trong `kdst_v1.json`.

## Hạn chế

- **Chỉ một góc quay.** Bài báo gốc đạt 88–96% vì kết hợp 3 góc, còn app chỉ có một điện thoại.
- **Không thấy đồ vật.** Bóng và dây không có trong khung xương, nên các bài có bóng kém tin cậy hơn.
- **Ít mẫu "chưa làm được"** (khoảng 24% tập train, rất ít ở C03).
- **Dữ liệu là trẻ Hàn Quốc, quay trong phòng thí nghiệm.** Video phụ huynh quay ở nhà (ánh sáng, khung hình, quần áo) sẽ khác. Cần thu dữ liệu thật, có đồng ý của phụ huynh, để train lại.
- Mỗi video chỉ được chứa **một lần thử của một bài**. Model không chấm từng bước và không cắt video dài.
- Train bằng MediaPipe (app) và bằng OpenPose (dataset) cho khung xương hơi khác nhau. **Cần kiểm tra lại trên vài video thật** quay bằng app trước khi đưa vào dùng.
- Đây là công cụ **gợi ý để theo dõi**, không phải chẩn đoán y khoa.
