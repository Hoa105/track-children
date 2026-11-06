-- 023 - Align review types with the approved content-management contract.

BEGIN;

UPDATE assessment.content_reviews SET review_type = 'medical' WHERE review_type = 'clinical';
UPDATE assessment.content_reviews SET review_type = 'media_rights' WHERE review_type = 'rights';

ALTER TABLE assessment.content_reviews
    DROP CONSTRAINT IF EXISTS content_reviews_review_type_check;
ALTER TABLE assessment.content_reviews
    ADD CONSTRAINT content_reviews_review_type_check
    CHECK (review_type IN ('medical','language','media_rights','qa'));

COMMIT;
