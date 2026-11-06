-- Rename the existing schema without copying or dropping assessment data.
-- Compatibility bridge for installations that used the previous schema name.
BEGIN;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'development') THEN
        IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'assessment') THEN
            -- Migration 001 created an older, unrelated assessment model.
            -- Preserve it under a separate name; never merge incompatible tables.
            IF to_regclass('assessment.assessment_domain_results') IS NULL
               OR to_regclass('assessment.assessments') IS NULL
               OR to_regclass('assessment.assessment_answers') IS NULL
               OR EXISTS (
                   SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                   WHERE n.nspname = 'assessment' AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
                     AND c.relname NOT IN ('assessments', 'assessment_answers', 'assessment_domain_results')
               )
               OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'assessment_legacy') THEN
                RAISE EXCEPTION 'Unexpected assessment schema or existing assessment_legacy; resolve the conflict before migrating';
            END IF;
            ALTER SCHEMA assessment RENAME TO assessment_legacy;
        END IF;
        ALTER SCHEMA development RENAME TO assessment;
    ELSIF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'assessment') THEN
        RAISE EXCEPTION 'Assessment schema is missing; apply migrations 021-024 first';
    END IF;
END;
$$;

-- PL/pgSQL function bodies retain textual schema names after ALTER SCHEMA.
CREATE OR REPLACE FUNCTION assessment.validate_assessment_question()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    item_kind text;
    item_set  uuid;
    assessment_set uuid;
BEGIN
    SELECT kind, question_set_id INTO item_kind, item_set
    FROM assessment.content_items
    WHERE id = NEW.content_item_id AND deleted_at IS NULL;
    SELECT question_set_id INTO assessment_set
    FROM assessment.assessments
    WHERE id = NEW.assessment_id;

    IF item_kind IS DISTINCT FROM 'skill'
       OR item_set IS DISTINCT FROM assessment_set THEN
        RAISE EXCEPTION 'assessment question must be an active skill in the selected question set';
    END IF;
    RETURN NEW;
END;
$$;

COMMIT;
