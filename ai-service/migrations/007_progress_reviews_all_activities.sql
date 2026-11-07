-- =====================================================================
-- 007 – Đánh giá tổng hợp gộp mọi hoạt động trong một khoảng thời gian
--   Ba mẹ chọn khoảng thời gian → AI gộp tất cả video đã nhận xét (mọi nhóm
--   hoạt động) vào một đánh giá. activity_group NULL = nhiều nhóm.
-- =====================================================================

ALTER TABLE ai_vision.progress_reviews
    ALTER COLUMN activity_group DROP NOT NULL;
