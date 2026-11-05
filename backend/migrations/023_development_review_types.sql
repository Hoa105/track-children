-- 023 - Align review types with the approved content-management contract.

BEGIN;

UPDATE development.content_reviews SET review_type = 'medical' WHERE review_type = 'clinical';
UPDATE development.content_reviews SET review_type = 'media_rights' WHERE review_type = 'rights';

ALTER TABLE development.content_reviews
    DROP CONSTRAINT IF EXISTS content_reviews_review_type_check;
ALTER TABLE development.content_reviews
    ADD CONSTRAINT content_reviews_review_type_check
    CHECK (review_type IN ('medical','language','media_rights','qa'));

COMMIT;
