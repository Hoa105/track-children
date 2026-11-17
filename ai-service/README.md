# AI Service

Service for rule-based NLP, indicator mapping, rule evaluation, and optional
LLM integrations.

```powershell
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```

## Database migrations

Start the local PostgreSQL containers from the repository root, then run:

```powershell
.\scripts\migrate.ps1 -Target ai
```

Migrations are stored in `ai-service/migrations/` and are applied in filename
order. The `public.schema_migrations` table records each applied migration.

## Nhận xét AI cho video nhật ký

Luồng: mobile (chi tiết hoạt động → **Thêm nhật ký**) → backend
`POST /children/{id}/diary/video-insights` → ai-service `/internal/video-insights`
→ worker → mobile polling `GET /children/{id}/diary/video-insights/{insightId}`.

1. **Backend** kiểm tra quyền (`diary`), consent của ba mẹ, xác định nhóm hoạt động
   và gửi kèm tiêu chí quan sát (`backend/app/features/diary_ai/criteria.py`).
2. **ai-service** lưu video tạm, xếp hàng (`ai_vision.diary_video_insights`, migration 004).
3. **Worker** (chạy trong tiến trình API):
   - kiểm tra video: 2–90 giây, không quá tối; lỗi thì trả lý do để ba mẹ quay lại;
   - giai đoạn 2, chỉ với vận động thô / tinh: MediaPipe đo số liệu (số bước, số lần
     nhảy, thời gian đứng một chân, số lần chụm ngón…), xem `app/pose/`;
   - gửi 16 khung hình + tiêu chí + số đo cho Gemini (mặc định) hoặc Claude, nhận JSON có cấu trúc
     (quan sát, nhận xét, điểm tích cực, gợi ý tiếp theo). Không chấm đạt / chưa đạt;
   - xóa video ngay khi xong (thành công, bị từ chối hoặc hết lượt thử).

### Cấu hình

| Biến | Ý nghĩa |
|---|---|
| `INTERNAL_TOKEN` | Bí mật dùng chung với `AI_SERVICE_TOKEN` của backend. Để trống thì API nội bộ trả 503 |
| `LLM_PROVIDER` | `gemini` (mặc định) hoặc `claude` |
| `GEMINI_API_KEY` | Khóa Gemini API (https://aistudio.google.com/apikey) |
| `GEMINI_MODEL` | Danh sách dự phòng, mặc định `gemini-3.8-flash,gemini-3.5-flash-lite`: model đầu quá tải hoặc quá 90 giây thì chuyển sang model sau |
| `ANTHROPIC_API_KEY`, `LLM_MODEL` | Khi `LLM_PROVIDER=claude`: khóa và model Claude (`claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`) |

### Test

```powershell
python -m pytest tests -q
```

Test không cần Postgres hay khóa API (dùng store trong bộ nhớ và client giả).
