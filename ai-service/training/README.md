# Train model chấm điểm 12 bài vận động thô K-DST

Model nhận chuỗi khung xương của bé, chấm 3 mức (chưa làm được / làm được nhưng loạng choạng / làm vững) cho bài phụ huynh đã chọn, và đoán xem video là bài nào. Kết quả chạy bằng `onnxruntime` trong ai-service, **không cần gọi API ngoài**.

## Dataset

Multiview child motor development dataset (Kim et al., GigaScience 2023), GigaDB [10.5524/102382](https://doi.org/10.5524/102382), giấy phép **CC0**.

- Gồm 399 trẻ (bài báo ghi 339 ở phần tóm tắt; dữ liệu thực có 399 mã trẻ), 20–71 tháng tuổi, chia 3 nhóm A/B/C, mỗi nhóm 4 bài (danh sách ở `app/kdst/items.py`).
- Khung xương OpenPose BODY_25. Mỗi bài được quay 3 góc: chính diện, phải 45°, trái 45°.
- Mỗi file là một lần thử ở một góc, được chuyên gia chấm Bad / Good / Perfect.

## Cách chạy

```powershell
# 1. Môi trường riêng (ngoài repo)
py -3.12 -m venv C:\ml\venv
C:\ml\venv\Scripts\pip install torch --index-url https://download.pytorch.org/whl/cu126
C:\ml\venv\Scripts\pip install -r training/requirements.txt

# 2. Tải dữ liệu (khoảng 730 MB)
$base = "https://s3.ap-northeast-1.wasabisys.com/gigadb-datasets/live/pub/10.5524/102001_103000/102382"
foreach ($f in "A_skel.zip","B_skel.zip","C_skel.zip") { curl.exe -L --retry 5 -C - -o "C:\ml\kdst-data\$f" "$base/$f" }

# 3. Chạy từ thư mục ai-service
C:\ml\venv\Scripts\python -m training.kdst.prepare --data-dir C:/ml/kdst-data --out C:/ml/kdst-data/kdst_v1.npz
C:\ml\venv\Scripts\python -m training.kdst.train --data C:/ml/kdst-data/kdst_v1.npz --out C:/ml/runs/kdst_v1
C:\ml\venv\Scripts\python -m training.kdst.export --run C:/ml/runs/kdst_v1 --out models/kdst --version kdst_v1
```

Riêng `models/kdst/` được commit (khoảng 2 MB), để build image ai-service không cần train lại. Các model MediaPipe trong `models/` vẫn bị ignore.

## Thiết kế

| Bước | File | Ghi chú |
|---|---|---|
| Định dạng chung | `app/kdst/skeleton.py` | 21 khớp có ở cả BODY_25 lẫn MediaPipe (COCO-17 + gót + mũi chân). Kênh `(x, y, mask)` |
| Chọn bé khi có nhiều người | `skeleton.pick_child` | Cùng quy tắc với `app/pose/landmarks.py` |
| Chuẩn hóa | `skeleton.normalize` | Gốc = hông trung bình của cả chuỗi; đơn vị = chiều dài thân |
| Chia dữ liệu | `kdst/prepare.py` | 70 / 15 / 15 **theo trẻ**, trong từng nhóm tuổi, seed 100 |
| Model | `kdst/model.py` | ST-GCN 6 khối, khoảng 0,5 triệu tham số (đủ nhỏ để train bằng CPU); 12 đầu chấm điểm + 1 đầu nhận diện bài |
| Train | `kdst/train.py` | Tăng cường dữ liệu: cắt đoạn, lật trái↔phải, xoay ±10°, co giãn, che khớp. Trọng số lớp, chọn checkpoint theo macro-F1 trên tập val |
| Đánh giá | `kdst/metrics.py` | So với baseline "luôn đoán mức phổ biến nhất"; có bảng ngưỡng tin cậy so với độ phủ |

Mỗi mẫu train chỉ dùng **một góc quay**, giống video quay bằng một điện thoại trong app. Bài báo gốc đạt 88–96% khi dùng nhiều góc, nhưng con số đó không áp dụng được cho trường hợp một góc.

Kết quả lần train gần nhất: xem `RESULTS.md`.

## Dùng trong ai-service

`app/kdst/items.py` và `app/kdst/skeleton.py` dùng chung cho cả lúc train lẫn lúc chạy thật, nên video phụ huynh được xử lý đúng như dữ liệu train.

1. Admin chọn **Bài K-DST** cho hoạt động (cột `activity.activities.kdst_item`, migration backend 016).
2. Backend gửi `kdstItem` kèm video sang ai-service.
3. ai-service (`app/insights/service.py`) chạy MediaPipe một lần, rồi dùng `app/kdst/scorer.py` (onnxruntime) để chấm.
4. Nếu model đủ tin cậy (đúng bài và xác suất ≥ `min_confidence`), ai-service trả nhận xét mẫu `app/kdst/templates.py` và **không gọi API**.
5. Nếu model không chắc, ai-service gọi LLM khi `KDST_LLM_FALLBACK=true`, hoặc nhờ ba mẹ quay lại khi `KDST_LLM_FALLBACK=false`.
6. Kết quả chấm luôn được lưu ở `ai_vision.diary_video_insights.kdst_assessment` (migration ai 005), không trả cho mobile.

Train model mới (ví dụ `kdst_v2`): xuất ra `models/kdst/`, rồi đặt `KDST_MODEL_PATH=./models/kdst/kdst_v2.onnx`. Nếu sửa `skeleton.normalize`, phải tăng `NORMALIZATION_VERSION` và train lại; ai-service sẽ từ chối nạp model có version chuẩn hóa không khớp.
