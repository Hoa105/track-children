-- Independent availability and reversible deletion; existing history is untouched.
BEGIN;
ALTER TABLE development.question_sets ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT false;
ALTER TABLE development.question_sets ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
CREATE INDEX IF NOT EXISTS ix_development_sets_available
    ON development.question_sets(age_months) WHERE is_active AND deleted_at IS NULL;
-- New content requires an explicit activation after publication.
ALTER TABLE development.content_items ALTER COLUMN is_active SET DEFAULT false;
COMMIT;
