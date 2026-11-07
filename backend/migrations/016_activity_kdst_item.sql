-- =====================================================================
-- 016 – Gắn hoạt động với bài vận động thô K-DST
--   Video nhật ký của hoạt động có kdst_item được ai-service chấm bằng model
--   tự train (ai-service/app/kdst) và trả nhận xét mẫu, không gọi LLM.
--   Model chỉ biết 12 bài này; hoạt động khác để NULL (dùng LLM như cũ).
--   A01 Đi lên cầu thang        A02 Đi xuống cầu thang   A03 Ném bóng qua đầu
--   A04 Đứng một chân 1 giây    B01 Đứng một chân 3 giây B02 Nhảy lò cò
--   B03 Bật xa bằng hai chân    B04 Bắt bóng             C01 Chặn bóng lăn bằng chân
--   C02 Đập bóng nảy            C03 Nhảy qua dây         C04 Nhảy dây
-- =====================================================================

ALTER TABLE activity.activities
    ADD COLUMN IF NOT EXISTS kdst_item varchar(3)
        CHECK (kdst_item IN ('A01','A02','A03','A04','B01','B02','B03','B04',
                             'C01','C02','C03','C04'));

COMMENT ON COLUMN activity.activities.kdst_item IS
    'Bài K-DST tương ứng: ai-service chấm video bằng model tự train thay vì LLM';

-- Hoạt động mẫu đã có trùng bài K-DST
UPDATE activity.activities SET kdst_item = 'A01'
WHERE title = 'Cùng leo cầu thang' AND kdst_item IS NULL;
