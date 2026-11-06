-- Independent availability and reversible deletion; existing history is untouched.
BEGIN;
ALTER TABLE assessment.question_sets ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT false;
ALTER TABLE assessment.question_sets ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
CREATE INDEX IF NOT EXISTS ix_assessment_sets_available
    ON assessment.question_sets(age_months) WHERE is_active AND deleted_at IS NULL;
-- New content requires an explicit activation after publication.
ALTER TABLE assessment.content_items ALTER COLUMN is_active SET DEFAULT false;
COMMIT;
