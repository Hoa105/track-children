-- =====================================================================
-- 011 – Ảnh / video nhật ký lưu trên MinIO
--   - diary_media.id do mobile sinh (uuid) để tải lên lặp lại không bị trùng
--   - File trên MinIO chỉ cần storage_key; url (link ngoài, cũ) không bắt buộc
--   - Bỏ ảnh base64 tạm lưu trong url ở 010: mobile còn bản gốc và tải lại lên MinIO
--   - Thứ tự file theo danh sách mobile gửi kèm nhật ký (file có thể tải lên sau)
-- =====================================================================

ALTER TABLE diary.diary_entries
    ADD COLUMN media_order uuid[] NOT NULL DEFAULT '{}';

DELETE FROM diary.diary_media WHERE storage_key IS NULL AND url LIKE 'data:%';

ALTER TABLE diary.diary_media
    ALTER COLUMN url DROP NOT NULL,
    ADD COLUMN content_type varchar(100),
    ADD CONSTRAINT diary_media_location_check
        CHECK (url IS NOT NULL OR storage_key IS NOT NULL);
