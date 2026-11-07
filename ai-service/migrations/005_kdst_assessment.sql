-- =====================================================================
-- 005 – Kết quả chấm 12 bài vận động thô K-DST bằng model tự train (app/kdst)
--   Hoạt động gắn bài K-DST: model chấm mức + nhận xét mẫu, không gọi LLM.
--   Model không chắc chắn → vẫn lưu kết quả ở đây rồi hỏi LLM, để sau này
--   đối chiếu model ↔ LLM ↔ nhãn chuyên gia.
--   Không trả cho mobile (phụ huynh không xem điểm số).
-- =====================================================================

-- { "modelVersion": "kdst_v1", "item": "B01",
--   "level": "not_yet" | "unsteady" | "steady" | null, "confidence": 0.83,
--   "predictedItem": "B01", "itemConfidence": 0.91,
--   "reason": "" | "no_body" | "other_item" | "low_confidence" }
-- llm_model = modelVersion và prompt_version = 'kdst-template-N' khi nhận xét do model tạo.
ALTER TABLE ai_vision.diary_video_insights
    ADD COLUMN IF NOT EXISTS kdst_assessment jsonb;

CREATE INDEX IF NOT EXISTS diary_video_insights_kdst_idx
    ON ai_vision.diary_video_insights ((kdst_assessment ->> 'item'))
    WHERE kdst_assessment IS NOT NULL;
