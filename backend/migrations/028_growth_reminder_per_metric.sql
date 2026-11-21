-- Migration 028: Per-metric growth reminder settings (mode + interval_days)
-- Thêm chế độ "Theo độ tuổi" vs "Tự điều chỉnh" và chu kỳ riêng cho từng chỉ số
ALTER TABLE growth.reminder_settings
    ADD COLUMN mode text NOT NULL DEFAULT 'age_based'
        CHECK(mode IN ('age_based', 'custom')),
    ADD COLUMN interval_days integer
        CHECK(interval_days IS NULL OR interval_days IN (15, 30, 60, 90, 180));
-- interval_days NULL khi mode=custom có nghĩa là Tắt chỉ số đó
-- Khi mode=age_based, interval_days bị bỏ qua (tự tính theo tuổi)

COMMENT ON COLUMN growth.reminder_settings.mode IS
    'age_based = tự động theo nhóm tuổi; custom = người dùng tự chọn';
COMMENT ON COLUMN growth.reminder_settings.interval_days IS
    'NULL = Tắt (khi mode=custom). Giá trị hợp lệ: 15/30/60/90/180';

ALTER TABLE notification.preferences
    ADD COLUMN IF NOT EXISTS send_minute integer NOT NULL DEFAULT 0
        CHECK(send_minute BETWEEN 0 AND 59);
