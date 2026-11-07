-- 021 - Consolidated assessment schema (formerly migrations 021, 023-025).
--
-- This is a new canonical schema for the CDC developmental assessment flow.
-- Legacy assessment tables are preserved in assessment_legacy for compatibility.
-- Do not store the same question/revision/review data in both schemas.
-- PostgreSQL 15+; run inside the migration runner transaction.

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

    END IF;
END;
$$;

-- Preserve the original assessment tables before creating the normalized model.
DO $$
BEGIN
    IF to_regclass('assessment.assessment_domain_results') IS NOT NULL THEN
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
END;
$$;

CREATE SCHEMA IF NOT EXISTS assessment;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- One published question set per age/version/locale. Questions and advice
-- content are stored separately below; this table only owns set identity.
CREATE TABLE IF NOT EXISTS assessment.question_sets (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code            text NOT NULL UNIQUE,
    age_months      smallint NOT NULL CHECK (age_months IN (2,4,6,9,12,15,18,24,30,36,48,60)),
    version         text NOT NULL,
    locale          text NOT NULL DEFAULT 'vi-VN',
    source_name     text NOT NULL DEFAULT 'CDC Developmental Milestones',
    is_active       boolean NOT NULL DEFAULT false,
    deleted_at      timestamptz,
    status          text NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft','in_review','published','archived')),
    created_by      uuid REFERENCES admin.admin_users(id) ON DELETE SET NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (age_months, version, locale)
);

CREATE INDEX IF NOT EXISTS ix_assessment_sets_available
    ON assessment.question_sets(age_months) WHERE is_active AND deleted_at IS NULL;

-- One identity row for either a skill or an advice variant. This replaces
-- separate question/content identity tables.
CREATE TABLE IF NOT EXISTS assessment.content_items (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    kind              text NOT NULL CHECK (kind IN ('skill','advice')),
    stable_code       text NOT NULL,
    question_set_id   uuid REFERENCES assessment.question_sets(id) ON DELETE RESTRICT,
    source_domain     text,
    app_domain        text,
    order_index       integer,
    current_revision  integer NOT NULL DEFAULT 1 CHECK (current_revision >= 1),
    published_revision integer CHECK (published_revision IS NULL OR published_revision >= 1),
    is_active         boolean NOT NULL DEFAULT false,
    deleted_at        timestamptz,
    created_by        uuid REFERENCES admin.admin_users(id) ON DELETE SET NULL,
    updated_by        uuid REFERENCES admin.admin_users(id) ON DELETE SET NULL,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (kind, stable_code),
    CHECK ((kind = 'skill' AND question_set_id IS NOT NULL AND order_index IS NOT NULL)
        OR (kind = 'advice' AND question_set_id IS NULL AND order_index IS NULL)),
    CHECK (source_domain IS NULL OR source_domain IN
        ('social_emotional','language_communication','cognitive','movement_physical')),
    CHECK (app_domain IS NULL OR app_domain IN
        ('social_emotional','language_communication','cognitive','gross_motor','fine_motor')),
    CHECK (published_revision IS NULL OR published_revision <= current_revision)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_assessment_skill_order
    ON assessment.content_items(question_set_id, order_index)
    WHERE kind = 'skill' AND deleted_at IS NULL;

-- The only table that owns editable text/media/source payloads. Old revisions
-- are append-only and are never overwritten.
CREATE TABLE IF NOT EXISTS assessment.content_revisions (
    content_item_id uuid NOT NULL REFERENCES assessment.content_items(id) ON DELETE RESTRICT,
    revision        integer NOT NULL CHECK (revision >= 1),
    locale          text NOT NULL DEFAULT 'vi-VN',
    payload         jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
    source_refs     jsonb NOT NULL DEFAULT '[]'::jsonb
                    CHECK (jsonb_typeof(source_refs) = 'array'),
    created_by      uuid REFERENCES admin.admin_users(id) ON DELETE SET NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (content_item_id, revision)
);

-- A published pointer must reference an existing revision of the same item.
ALTER TABLE assessment.content_items
    DROP CONSTRAINT IF EXISTS content_items_published_revision_fk;
ALTER TABLE assessment.content_items
    ADD CONSTRAINT content_items_published_revision_fk
    FOREIGN KEY (id, published_revision)
    REFERENCES assessment.content_revisions(content_item_id, revision)
    DEFERRABLE INITIALLY DEFERRED;

-- One append-only review stream for both skill and advice content.
CREATE TABLE IF NOT EXISTS assessment.content_reviews (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    content_item_id uuid NOT NULL,
    revision        integer NOT NULL,
    review_type     text NOT NULL CHECK (review_type IN ('medical','language','media_rights','qa')),
    decision        text NOT NULL CHECK (decision IN ('approved','rejected')),
    reviewer_id     uuid NOT NULL REFERENCES admin.admin_users(id) ON DELETE RESTRICT,
    evidence_ref    text,
    note            text,
    reviewed_at     timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (content_item_id, revision)
        REFERENCES assessment.content_revisions(content_item_id, revision)
        ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS ix_assessment_content_reviews
    ON assessment.content_reviews(content_item_id, revision, review_type, reviewed_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS assessment.assessments (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id              uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    caregiver_id          uuid REFERENCES account.users(id) ON DELETE SET NULL,
    question_set_id       uuid NOT NULL REFERENCES assessment.question_sets(id) ON DELETE RESTRICT,
    age_basis             text NOT NULL DEFAULT 'chronological'
                          CHECK (age_basis IN ('chronological','corrected_clinician_guided')),
    birth_date_used       date,
    due_date_used         date,
    regression_response    text CHECK (regression_response IN ('yes','no','unsure')),
    caregiver_concern     text CHECK (caregiver_concern IN ('yes','no')),
    caregiver_note        text CHECK (caregiver_note IS NULL OR length(caregiver_note) <= 1000),
    status                text NOT NULL DEFAULT 'in_progress'
                          CHECK (status IN ('in_progress','completed','abandoned')),
    update_version        integer NOT NULL DEFAULT 1 CHECK (update_version >= 1),
    started_at            timestamptz NOT NULL DEFAULT now(),
    completed_at          timestamptz,
    created_at            timestamptz NOT NULL DEFAULT now(),
    CHECK (completed_at IS NULL OR status = 'completed')
);
CREATE INDEX IF NOT EXISTS ix_assessment_assessments_child_history
    ON assessment.assessments(child_id, started_at DESC, id);

-- Normalized question snapshot for one assessment. This replaces a second
-- question_snapshot JSONB copy and pins the exact revision used.
CREATE TABLE IF NOT EXISTS assessment.assessment_questions (
    assessment_id   uuid NOT NULL REFERENCES assessment.assessments(id) ON DELETE CASCADE,
    content_item_id uuid NOT NULL,
    revision        integer NOT NULL,
    order_index     integer NOT NULL CHECK (order_index >= 0),
    PRIMARY KEY (assessment_id, content_item_id),
    UNIQUE (assessment_id, order_index),
    FOREIGN KEY (content_item_id, revision)
        REFERENCES assessment.content_revisions(content_item_id, revision)
        ON DELETE RESTRICT,
    FOREIGN KEY (content_item_id)
        REFERENCES assessment.content_items(id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS assessment.assessment_answers (
    assessment_id   uuid NOT NULL,
    content_item_id uuid NOT NULL,
    answer          text NOT NULL CHECK (answer IN ('achieved','not_yet','not_observed')),
    note            text CHECK (note IS NULL OR length(note) <= 1000),
    answered_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (assessment_id, content_item_id),
    FOREIGN KEY (assessment_id, content_item_id)
        REFERENCES assessment.assessment_questions(assessment_id, content_item_id)
        ON DELETE CASCADE
);

-- Keep the normalized snapshot internally consistent: only skill items from
-- the selected set can be pinned as assessment questions.
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

DROP TRIGGER IF EXISTS trg_assessment_validate_assessment_question
    ON assessment.assessment_questions;
CREATE TRIGGER trg_assessment_validate_assessment_question
    BEFORE INSERT OR UPDATE ON assessment.assessment_questions
    FOR EACH ROW EXECUTE FUNCTION assessment.validate_assessment_question();

-- One immutable result per completed assessment. JSON is intentional here:
-- these are historical snapshots, not operational entities to be joined.
CREATE TABLE IF NOT EXISTS assessment.assessment_results (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assessment_id            uuid NOT NULL UNIQUE
                             REFERENCES assessment.assessments(id) ON DELETE RESTRICT,
    rules_version            text NOT NULL,
    question_set_version     text NOT NULL,
    skill_content_versions   jsonb NOT NULL CHECK (jsonb_typeof(skill_content_versions) = 'object'),
    advice_content_versions  jsonb NOT NULL CHECK (jsonb_typeof(advice_content_versions) = 'object'),
    engine_snapshot          jsonb NOT NULL CHECK (jsonb_typeof(engine_snapshot) = 'object'),
    view_snapshot            jsonb NOT NULL CHECK (jsonb_typeof(view_snapshot) = 'object'),
    snapshot_schema_version  text NOT NULL,
    idempotency_key          text,
    created_at               timestamptz NOT NULL DEFAULT now(),
    UNIQUE (assessment_id, idempotency_key)
);

-- Reuse the existing admin audit table instead of creating a duplicate
-- assessment audit table. Content lifecycle events should use entity_type
-- values such as assessment.content_item and assessment.assessment_result.

CREATE OR REPLACE FUNCTION assessment.reject_immutable_update()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION '% is append-only; create a new revision/event', TG_TABLE_NAME;
END;
$$;

DROP TRIGGER IF EXISTS trg_assessment_content_revision_immutable
    ON assessment.content_revisions;
CREATE TRIGGER trg_assessment_content_revision_immutable
    BEFORE UPDATE OR DELETE ON assessment.content_revisions
    FOR EACH ROW EXECUTE FUNCTION assessment.reject_immutable_update();

DROP TRIGGER IF EXISTS trg_assessment_content_review_immutable
    ON assessment.content_reviews;
CREATE TRIGGER trg_assessment_content_review_immutable
    BEFORE UPDATE OR DELETE ON assessment.content_reviews
    FOR EACH ROW EXECUTE FUNCTION assessment.reject_immutable_update();

DROP TRIGGER IF EXISTS trg_assessment_result_immutable
    ON assessment.assessment_results;
CREATE TRIGGER trg_assessment_result_immutable
    BEFORE UPDATE ON assessment.assessment_results
    FOR EACH ROW EXECUTE FUNCTION assessment.reject_immutable_update();

COMMIT;
