-- =====================================================================
-- ?NG D?NG CHAM S�C & THEO D�I S? PH�T TRI?N C?A TR? 0�6 TU?I
-- PostgreSQL 15+  |  1 database, m?i nh�m ch?c nang = 1 schema (16 schema)
--   Backend   : account, admin, child, growth, health, reference, criteria,
--               assessment, activity, diary, notification, community, report
-- Flutter app KH�NG k?t n?i tr?c ti?p DB: g?i REST API c?a Backend
-- (cache offline ph�a mobile xem file schema_flutter_local.sql)
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;     -- email kh�ng ph�n bi?t hoa/thu?ng

CREATE SCHEMA IF NOT EXISTS common;   -- h�m d�ng chung
CREATE SCHEMA IF NOT EXISTS account;
CREATE SCHEMA IF NOT EXISTS admin;
CREATE SCHEMA IF NOT EXISTS child;
CREATE SCHEMA IF NOT EXISTS growth;
CREATE SCHEMA IF NOT EXISTS health;
CREATE SCHEMA IF NOT EXISTS reference;
CREATE SCHEMA IF NOT EXISTS criteria;
CREATE SCHEMA IF NOT EXISTS assessment;
CREATE SCHEMA IF NOT EXISTS activity;
CREATE SCHEMA IF NOT EXISTS diary;
CREATE SCHEMA IF NOT EXISTS notification;
CREATE SCHEMA IF NOT EXISTS community;
CREATE SCHEMA IF NOT EXISTS report;

-- ---------------------------------------------------------------------
-- H�m ti?n �ch: t? c?p nh?t updated_at
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION common.set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- PH?N 1. BACKEND (13 schema)
-- =====================================================================

-- ---------------------------------------------------------------------
-- F01 � T�i kho?n ph? huynh & quy?n ri�ng tu
-- ---------------------------------------------------------------------
CREATE TABLE account.users (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email           citext UNIQUE,
    phone           varchar(16) UNIQUE CHECK (phone ~ '^\+[1-9][0-9]{7,14}$'),   -- chu?n E.164, vd +84912345678
    password_hash   text NOT NULL,
    full_name       varchar(150) NOT NULL,
    avatar_url      text,
    gender          varchar(10) CHECK (gender IN ('male','female','other')),
    date_of_birth   date,
    relationship    varchar(30),                 -- m? / b? / ngu?i gi�m h?...
    status          varchar(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','active','locked','pending_deletion','deleted')),
    email_verified_at timestamptz,
    phone_verified_at timestamptz,
    last_login_at   timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

-- OTP / token x�c th?c dang k�, qu�n m?t kh?u (F01.1, F01.4)
CREATE TABLE account.verification_codes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid REFERENCES account.users(id) ON DELETE CASCADE,
    target      varchar(255) NOT NULL,            -- email ho?c s? di?n tho?i
    purpose     varchar(30) NOT NULL CHECK (purpose IN ('register','reset_password','change_email','change_phone')),
    code_hash   text NOT NULL,
    attempts    smallint NOT NULL DEFAULT 0,
    expires_at  timestamptz NOT NULL,
    used_at     timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON account.verification_codes (target, purpose);

-- Phi�n dang nh?p / refresh token (F01.2)
CREATE TABLE account.user_sessions (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    refresh_token_hash  text NOT NULL UNIQUE,
    device_id           varchar(100),
    device_name         varchar(100),
    platform            varchar(10) CHECK (platform IN ('android','ios','web')),
    ip_address          inet,
    expires_at          timestamptz NOT NULL,
    revoked_at          timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON account.user_sessions (user_id);

-- FCM token d? d?y th�ng b�o (F08)
CREATE TABLE account.device_tokens (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    fcm_token   text NOT NULL UNIQUE,
    platform    varchar(10) NOT NULL CHECK (platform IN ('android','ios')),
    is_active   boolean NOT NULL DEFAULT true,
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- �i?u kho?n & ch�nh s�ch d? li?u theo phi�n b?n (F01.5)
CREATE TABLE account.legal_documents (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    doc_type      varchar(30) NOT NULL CHECK (doc_type IN ('terms','privacy','data_policy')),
    version       varchar(20) NOT NULL,
    content       text NOT NULL,
    is_required   boolean NOT NULL DEFAULT true,
    effective_at  timestamptz NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (doc_type, version)
);

CREATE TABLE account.user_consents (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    document_id  uuid NOT NULL REFERENCES account.legal_documents(id),
    is_accepted  boolean NOT NULL,
    ip_address   inet,
    consented_at timestamptz NOT NULL DEFAULT now(),
    withdrawn_at timestamptz,
    UNIQUE (user_id, document_id)
);

-- Y�u c?u x�a t�i kho?n & d? li?u (F01.6)
CREATE TABLE account.data_deletion_requests (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid NOT NULL REFERENCES account.users(id),
    reason        text,
    status        varchar(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','cancelled','processing','completed')),
    scheduled_at  timestamptz,                    -- v� d?: sau 30 ng�y cho ph�p h?y
    requested_at  timestamptz NOT NULL DEFAULT now(),
    completed_at  timestamptz
);
CREATE UNIQUE INDEX one_open_deletion_request
    ON account.data_deletion_requests (user_id) WHERE status IN ('pending','processing');

-- ---------------------------------------------------------------------
-- F11 � Admin & ph�n quy?n
-- ---------------------------------------------------------------------
CREATE TABLE admin.admin_users (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email          citext NOT NULL UNIQUE,
    password_hash  text NOT NULL,
    full_name      varchar(150) NOT NULL,
    status         varchar(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','locked')),
    last_login_at  timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE admin.roles (
    id          serial PRIMARY KEY,
    code        varchar(50) NOT NULL UNIQUE,      -- super_admin, content_manager, moderator, support
    name        varchar(100) NOT NULL,
    description text
);

CREATE TABLE admin.permissions (
    id          serial PRIMARY KEY,
    code        varchar(100) NOT NULL UNIQUE,     -- vd: criteria.write, kb.manage, user.lock
    description text
);

CREATE TABLE admin.role_permissions (
    role_id       int NOT NULL REFERENCES admin.roles(id) ON DELETE CASCADE,
    permission_id int NOT NULL REFERENCES admin.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE admin.admin_user_roles (
    admin_user_id uuid NOT NULL REFERENCES admin.admin_users(id) ON DELETE CASCADE,
    role_id       int  NOT NULL REFERENCES admin.roles(id) ON DELETE CASCADE,
    PRIMARY KEY (admin_user_id, role_id)
);

-- Nh?t k� thao t�c c?a admin (d�ng chung cho F11�F22)
CREATE TABLE admin.admin_audit_logs (
    id            bigserial PRIMARY KEY,
    admin_user_id uuid REFERENCES admin.admin_users(id),
    action        varchar(50) NOT NULL,           -- create / update / delete / publish / lock ...
    entity_type   varchar(50) NOT NULL,
    entity_id     text,
    before_data   jsonb,
    after_data    jsonb,
    ip_address    inet,
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON admin.admin_audit_logs (entity_type, entity_id);
CREATE INDEX ON admin.admin_audit_logs (created_at);

-- ---------------------------------------------------------------------
-- F02 � H? so tr?  |  F23 � Chia s? h? so tr? v?i ngu?i cham s�c
-- ---------------------------------------------------------------------
CREATE TABLE child.children (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id    uuid NOT NULL REFERENCES account.users(id),   -- NGU?N DUY NH?T x�c d?nh ch? h? so (d?i du?c: F23.9)
    full_name        varchar(150) NOT NULL,
    nickname         varchar(50),
    date_of_birth    date NOT NULL,
    gender           varchar(10) NOT NULL CHECK (gender IN ('male','female')),  -- c?n cho chu?n WHO
    avatar_url       text,
    gestational_weeks smallint CHECK (gestational_weeks BETWEEN 22 AND 45),     -- t�nh tu?i hi?u ch?nh tr? sinh non
    birth_weight_kg  numeric(4,2),
    birth_height_cm  numeric(4,1),
    blood_type       varchar(5),
    allergies        text,
    note             text,
    deleted_at       timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON child.children (owner_user_id) WHERE deleted_at IS NULL;

-- CH? ch?a ngu?i cham s�c du?c chia s?. Ch? h? so n?m ? children.owner_user_id.
-- Chuy?n quy?n ch? (F23.9) l�m trong 1 transaction:
--   1) x�a d�ng member c?a ch? m?i  2) UPDATE children.owner_user_id  3) th�m ch? cu l�m caregiver
CREATE TABLE child.child_members (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id    uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    relationship varchar(30),                     -- b?, �ng, b�, ngu?i gi�m h?...
    status      varchar(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','revoked','left')),
    joined_at   timestamptz NOT NULL DEFAULT now(),
    ended_at    timestamptz,
    UNIQUE (child_id, user_id)
);

-- Ch?n ch? h? so b? th�m l�m caregiver (tr�nh 1 ngu?i c� 2 vai tr�)
CREATE OR REPLACE FUNCTION child.prevent_owner_as_member() RETURNS trigger AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM child.children c WHERE c.id = NEW.child_id AND c.owner_user_id = NEW.user_id) THEN
    RAISE EXCEPTION 'User % is already the owner of child %', NEW.user_id, NEW.child_id;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_child_members_not_owner BEFORE INSERT OR UPDATE OF child_id, user_id ON child.child_members
  FOR EACH ROW EXECUTE FUNCTION child.prevent_owner_as_member();

-- Quy?n theo t?ng m?c d? li?u: Kh�ng xem / Xem / Xem & s?a (F23.2)
CREATE TABLE child.child_member_permissions (
    member_id   uuid NOT NULL REFERENCES child.child_members(id) ON DELETE CASCADE,
    data_scope  varchar(20) NOT NULL
                CHECK (data_scope IN ('profile','growth','assessment','vaccination','teething','diary','chatbot')),
    access_level varchar(10) NOT NULL DEFAULT 'none' CHECK (access_level IN ('none','view','edit')),
    PRIMARY KEY (member_id, data_scope)
);

-- L?i m?i qua email / S�T / m� m?i (F23.1, F23.3)
CREATE TABLE child.child_invitations (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id       uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    inviter_id     uuid NOT NULL REFERENCES account.users(id),
    invitee_email  citext,
    invitee_phone  varchar(16) CHECK (invitee_phone ~ '^\+[1-9][0-9]{7,14}$'),   -- E.164
    invitee_user_id uuid REFERENCES account.users(id),
    invite_code    varchar(12) UNIQUE,
    relationship   varchar(30),
    proposed_permissions jsonb NOT NULL DEFAULT '{}'::jsonb,   -- {"growth":"view","diary":"edit"}
    status         varchar(20) NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','accepted','declined','expired','cancelled')),
    expires_at     timestamptz NOT NULL,
    responded_at   timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON child.child_invitations (child_id, status);

-- L?ch s? c?p nh?t d? li?u theo ngu?i th?c hi?n (F23.10 � option)
CREATE TABLE child.child_data_change_logs (
    id          bigserial PRIMARY KEY,
    child_id    uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    user_id     uuid REFERENCES account.users(id),
    data_scope  varchar(20) NOT NULL,
    entity_type varchar(50) NOT NULL,
    entity_id   uuid,
    action      varchar(10) NOT NULL CHECK (action IN ('create','update','delete')),
    changes     jsonb,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON child.child_data_change_logs (child_id, created_at DESC);

-- ---------------------------------------------------------------------
-- F04 � Tang tru?ng th? ch?t (chu?n WHO)
-- ---------------------------------------------------------------------
-- B?ng chu?n WHO (LMS) � import 1 l?n t? WHO Child Growth Standards
CREATE TABLE growth.who_growth_standards (
    indicator   varchar(10) NOT NULL CHECK (indicator IN ('wfa','lhfa','wfl','wfh','bmifa','hcfa')),
    sex         varchar(10) NOT NULL CHECK (sex IN ('male','female')),
    x_type      varchar(10) NOT NULL CHECK (x_type IN ('age_days','length_cm','height_cm')),
    x_value     numeric(7,2) NOT NULL,
    l           numeric(10,6),
    m           numeric(10,6) NOT NULL,
    s           numeric(10,6) NOT NULL,
    sd_neg3 numeric(8,3), sd_neg2 numeric(8,3), sd_neg1 numeric(8,3),
    sd_0    numeric(8,3),
    sd_pos1 numeric(8,3), sd_pos2 numeric(8,3), sd_pos3 numeric(8,3),
    version     varchar(20) NOT NULL DEFAULT 'WHO-2006',
    PRIMARY KEY (indicator, sex, x_type, x_value, version)
);

-- M?i S? �O l� m?t d�ng, c� ng�y do ri�ng (F04.1, F04.5)
-- C�n n?ng, chi?u cao, v�ng d?u c� th? do ? c�c ng�y kh�c nhau
CREATE TABLE growth.growth_measurements (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id      uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    metric        varchar(20) NOT NULL CHECK (metric IN ('weight','height','head_circumference')),
    value         numeric(6,2) NOT NULL CHECK (value > 0),   -- weight: kg | height, head_circumference: cm
    measure_position varchar(10) CHECK (measure_position IN ('lying','standing')),  -- ch? d�ng cho height
    measured_at   date NOT NULL,
    age_in_days   int  NOT NULL,                   -- snapshot tu?i t?i ng�y do
    note          text,
    created_by    uuid REFERENCES account.users(id),
    updated_by    uuid REFERENCES account.users(id),
    deleted_by    uuid REFERENCES account.users(id),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    deleted_at    timestamptz,
    UNIQUE (id, child_id)                          -- d? growth_evaluations ki?m tra c�ng tr?
);
-- M?i ch? s? ch? c� 1 s? do / ng�y; nh?p l?i c�ng ng�y th� c?p nh?t
CREATE UNIQUE INDEX uq_growth_measurement_day
    ON growth.growth_measurements (child_id, metric, measured_at) WHERE deleted_at IS NULL;
-- V? bi?u d? / l?ch s? t?ng ch? s?
CREATE INDEX ON growth.growth_measurements (child_id, metric, measured_at DESC) WHERE deleted_at IS NULL;

-- K?t qu? Z-score / BMI / ph�n lo?i (F04.3)
-- measurement_id = s? do ch�nh; paired_measurement_id = s? do gh�p c?p
-- (wfl/wfh/bmifa c?n c? c�n n?ng v� chi?u cao, c� th? do ? 2 ng�y kh�c nhau)
CREATE TABLE growth.growth_evaluations (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id              uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    indicator             varchar(10) NOT NULL CHECK (indicator IN ('wfa','lhfa','wfl','wfh','bmifa','hcfa')),
    measurement_id        uuid NOT NULL,
    paired_measurement_id uuid,
    evaluated_at_date     date NOT NULL,            -- ng�y d�ng d? d�nh gi� (ng�y c?a s? do m?i nh?t trong c?p)
    value                 numeric(7,2) NOT NULL,    -- gi� tr? do (ho?c BMI t�nh du?c)
    z_score               numeric(5,2),
    percentile            numeric(5,2),
    classification        varchar(30),              -- normal, underweight, stunted, overweight, ...
    standard_version      varchar(20) NOT NULL DEFAULT 'WHO-2006',
    created_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (measurement_id, indicator),
    -- Kh�a ngo?i k�p: s? do (v� s? do gh�p c?p) b?t bu?c thu?c C�NG child_id v?i d�nh gi�
    FOREIGN KEY (measurement_id, child_id)
        REFERENCES growth.growth_measurements (id, child_id) ON DELETE CASCADE,
    FOREIGN KEY (paired_measurement_id, child_id)
        REFERENCES growth.growth_measurements (id, child_id) ON DELETE SET NULL (paired_measurement_id)  -- PG 15+
);
CREATE INDEX ON growth.growth_evaluations (child_id, indicator, evaluated_at_date DESC);

-- ---------------------------------------------------------------------
-- F05 � Cham s�c s?c kh?e co b?n
-- ---------------------------------------------------------------------
-- Lu?ng s?a tham kh?o theo tu?i (F05.1)
CREATE TABLE health.milk_reference_rules (
    id             serial PRIMARY KEY,
    age_from_days  int NOT NULL,
    age_to_days    int NOT NULL,
    feeds_per_day_min smallint,
    feeds_per_day_max smallint,
    ml_per_feed_min   int,
    ml_per_feed_max   int,
    ml_per_kg_per_day numeric(5,1),
    note           text,
    source_id      uuid,                           -- FK -> reference_sources (th�m b�n du?i)
    is_active      boolean NOT NULL DEFAULT true
);

-- Danh m?c v?c xin & l?ch ti�m theo m?c tu?i (F05.2, F16.1)
CREATE TABLE health.vaccines (
    id            serial PRIMARY KEY,
    code          varchar(30) NOT NULL UNIQUE,
    name          varchar(150) NOT NULL,
    disease       varchar(200),
    is_mandatory  boolean NOT NULL DEFAULT false,  -- TCMR hay d?ch v?
    description   text,
    is_active     boolean NOT NULL DEFAULT true
);

CREATE TABLE health.vaccine_schedules (
    id              serial PRIMARY KEY,
    vaccine_id      int NOT NULL REFERENCES health.vaccines(id),
    dose_number     smallint NOT NULL DEFAULT 1,
    age_from_days   int NOT NULL,
    age_to_days     int,
    min_interval_days int,                         -- kho?ng c�ch t?i thi?u v?i mui tru?c
    note            text,
    UNIQUE (vaccine_id, dose_number)
);

CREATE TABLE health.child_vaccinations (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id     uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    schedule_id  int NOT NULL REFERENCES health.vaccine_schedules(id),
    status       varchar(15) NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','skipped')),
    vaccinated_at date,
    place        varchar(200),
    lot_number   varchar(50),
    reaction_note text,
    created_by   uuid REFERENCES account.users(id),
    updated_by   uuid REFERENCES account.users(id),
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (child_id, schedule_id),
    -- �� ti�m <=> c� ng�y ti�m; chua ti�m / b? qua th� kh�ng c� ng�y ti�m
    CHECK ((status = 'done' AND vaccinated_at IS NOT NULL) OR (status <> 'done' AND vaccinated_at IS NULL))
);

-- M?c rang (F05.4, F16.2)
CREATE TABLE health.tooth_references (
    code            varchar(10) PRIMARY KEY,       -- vd: UL-A (h�m tr�n, tr�i, rang c?a gi?a)
    name            varchar(100) NOT NULL,
    jaw             varchar(5) CHECK (jaw IN ('upper','lower')),
    side            varchar(5) CHECK (side IN ('left','right')),
    typical_month_from smallint,
    typical_month_to   smallint
);

CREATE TABLE health.child_teeth (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id    uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    tooth_code  varchar(10) NOT NULL REFERENCES health.tooth_references(code),
    erupted_at  date NOT NULL,
    note        text,
    created_by  uuid REFERENCES account.users(id),
    updated_by  uuid REFERENCES account.users(id),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (child_id, tooth_code)
);

-- ---------------------------------------------------------------------
-- F13 � Ngu?n & d? li?u tham chi?u ph�t tri?n
-- ---------------------------------------------------------------------
CREATE TABLE reference.reference_sources (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title         varchar(300) NOT NULL,
    organization  varchar(200),                    -- WHO, UNICEF, B? Y t?, CDC...
    authors       text,
    publish_year  smallint,
    url           text,
    source_type   varchar(30),                     -- guideline, paper, book, standard
    note          text,
    is_active     boolean NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE health.milk_reference_rules
    ADD CONSTRAINT fk_milk_source FOREIGN KEY (source_id) REFERENCES reference.reference_sources(id);

-- Phi�n b?n b? d? li?u tham chi?u d�ng khi ph�n t�ch (F13.3)
CREATE TABLE reference.reference_data_versions (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version       varchar(20) NOT NULL UNIQUE,
    description   text,
    status        varchar(15) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','retired')),
    activated_at  timestamptz,
    created_by    uuid REFERENCES admin.admin_users(id),
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX one_active_reference_version ON reference.reference_data_versions ((true)) WHERE status = 'active';

CREATE TABLE reference.reference_contents (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id   uuid NOT NULL REFERENCES reference.reference_sources(id) ON DELETE CASCADE,
    data_version_id uuid REFERENCES reference.reference_data_versions(id),
    title       varchar(300),
    content     text NOT NULL,
    page_ref    varchar(50),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- F12 � B? ti�u ch� & c�u h?i d�nh gi� ph�t tri?n
-- ---------------------------------------------------------------------
CREATE TABLE criteria.developmental_domains (
    id          serial PRIMARY KEY,
    code        varchar(30) NOT NULL UNIQUE,       -- gross_motor, fine_motor, language, cognitive, social_emotional
    name        varchar(100) NOT NULL,
    description text,
    icon_url    text,                              -- hi?n th? ? m�n danh s�ch linh v?c (F09.1)
    color_hex   varchar(9),
    sort_order  smallint NOT NULL DEFAULT 0,
    is_active   boolean NOT NULL DEFAULT true
);

CREATE TABLE criteria.age_milestones (                  -- c�c m?c tu?i (vd: 2, 4, 6, 9, 12, 18, 24, 36, 48, 60, 72 th�ng)
    id          serial PRIMARY KEY,
    label       varchar(50) NOT NULL,
    age_from_months smallint NOT NULL,
    age_to_months   smallint NOT NULL,
    sort_order  smallint NOT NULL DEFAULT 0,
    CHECK (age_to_months >= age_from_months)
);

CREATE TABLE criteria.criteria_versions (               -- v�ng d?i: draft -> published -> archived (F12.2)
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version       varchar(20) NOT NULL UNIQUE,
    name          varchar(200),
    description   text,
    status        varchar(15) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
    published_at  timestamptz,
    published_by  uuid REFERENCES admin.admin_users(id),
    created_by    uuid REFERENCES admin.admin_users(id),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX one_published_criteria_version ON criteria.criteria_versions ((true)) WHERE status = 'published';

CREATE TABLE criteria.criteria (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version_id    uuid NOT NULL REFERENCES criteria.criteria_versions(id) ON DELETE CASCADE,
    domain_id     int  NOT NULL REFERENCES criteria.developmental_domains(id),
    milestone_id  int  NOT NULL REFERENCES criteria.age_milestones(id),
    code          varchar(30) NOT NULL,
    title         varchar(300) NOT NULL,
    description   text,
    is_red_flag   boolean NOT NULL DEFAULT false,   -- d?u hi?u c?n luu �
    sort_order    smallint NOT NULL DEFAULT 0,
    is_active     boolean NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (version_id, code)
);
CREATE INDEX ON criteria.criteria (version_id, milestone_id, domain_id);

CREATE TABLE criteria.criteria_questions (              -- nhi?u c�u h?i / 1 ti�u ch� (F12.3)
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    criterion_id  uuid NOT NULL REFERENCES criteria.criteria(id) ON DELETE CASCADE,
    question_text text NOT NULL,
    hint_text     text,                             -- g?i � quan s�t / v� d?
    media_url     text,
    answer_type   varchar(15) NOT NULL DEFAULT 'three_level'
                  CHECK (answer_type IN ('yes_no','three_level')),
    sort_order    smallint NOT NULL DEFAULT 0,
    is_active     boolean NOT NULL DEFAULT true
);

-- Li�n k?t ti�u ch� <-> n?i dung tham chi?u (F13.2)
CREATE TABLE criteria.criterion_references (
    criterion_id  uuid NOT NULL REFERENCES criteria.criteria(id) ON DELETE CASCADE,
    reference_content_id uuid NOT NULL REFERENCES reference.reference_contents(id) ON DELETE CASCADE,
    PRIMARY KEY (criterion_id, reference_content_id)
);

-- ---------------------------------------------------------------------
-- F06 � ��nh gi� & ph�n t�ch s? ph�t tri?n (F15 xem tr�n Admin)
-- ---------------------------------------------------------------------
CREATE TABLE assessment.assessments (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id        uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    conducted_by    uuid REFERENCES account.users(id),
    criteria_version_id uuid NOT NULL REFERENCES criteria.criteria_versions(id),
    milestone_id    int NOT NULL REFERENCES criteria.age_milestones(id),
    assessment_type varchar(15) NOT NULL DEFAULT 'periodic'
                    CHECK (assessment_type IN ('periodic','quick_monthly')),  -- hi?n app ch? c� 1 lu?ng -> d�ng 'periodic'
    age_in_days     int NOT NULL,
    status          varchar(15) NOT NULL DEFAULT 'in_progress'
                    CHECK (status IN ('in_progress','completed','abandoned')),
    overall_level   varchar(20) CHECK (overall_level IN ('on_track','monitor','needs_support')),
    summary_text    text,                           -- t�m t?t do AI sinh
    started_at      timestamptz NOT NULL DEFAULT now(),
    completed_at    timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON assessment.assessments (child_id, completed_at DESC);

CREATE TABLE assessment.assessment_answers (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assessment_id uuid NOT NULL REFERENCES assessment.assessments(id) ON DELETE CASCADE,
    question_id   uuid NOT NULL REFERENCES criteria.criteria_questions(id),
    criterion_id  uuid NOT NULL REFERENCES criteria.criteria(id),
    answer        varchar(15) NOT NULL CHECK (answer IN ('yes','sometimes','not_yet','not_observed')),
    score         smallint,                         -- 2 / 1 / 0
    note          text,
    answered_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (assessment_id, question_id)
);

CREATE TABLE assessment.assessment_domain_results (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assessment_id uuid NOT NULL REFERENCES assessment.assessments(id) ON DELETE CASCADE,
    domain_id     int NOT NULL REFERENCES criteria.developmental_domains(id),
    score_percent numeric(5,2),
    level         varchar(20) NOT NULL CHECK (level IN ('on_track','monitor','needs_support')),
    analysis_text text,                             -- ph�n t�ch AI theo linh v?c
    recommended_activity_ids uuid[],
    UNIQUE (assessment_id, domain_id)
);

-- ---------------------------------------------------------------------
-- F20 / F09 � Ho?t d?ng h? tr? ph�t tri?n
-- ---------------------------------------------------------------------
CREATE TABLE activity.activities (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title         varchar(300) NOT NULL,
    summary       text,
    content       text NOT NULL,                    -- markdown / HTML
    activity_type varchar(20) NOT NULL
                  CHECK (activity_type IN ('play','reading','music','physical','daily_care','article','video')),
    age_from_months smallint NOT NULL,
    age_to_months   smallint NOT NULL,
    duration_minutes smallint,
    materials     text,
    thumbnail_url text,
    status        varchar(15) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','hidden')),
    created_by    uuid REFERENCES admin.admin_users(id),
    published_at  timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON activity.activities (status, age_from_months, age_to_months);
-- L?c ho?t d?ng theo linh v?c: d�ng activity_domains(domain_id, activity_id)

CREATE TABLE activity.activity_domains (
    activity_id uuid NOT NULL REFERENCES activity.activities(id) ON DELETE CASCADE,
    domain_id   int  NOT NULL REFERENCES criteria.developmental_domains(id),
    PRIMARY KEY (activity_id, domain_id)
);
CREATE INDEX ON activity.activity_domains (domain_id, activity_id);

-- Hu?ng d?n th?c hi?n t?ng bu?c (m�n chi ti?t ho?t d?ng, F09.2)
CREATE TABLE activity.activity_steps (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id uuid NOT NULL REFERENCES activity.activities(id) ON DELETE CASCADE,
    step_number smallint NOT NULL,
    title       varchar(200),
    instruction text NOT NULL,
    image_url   text,
    UNIQUE (activity_id, step_number)
);

-- Video / ?nh / �m thanh minh h?a (F09.2, F20.3)
CREATE TABLE activity.activity_media (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id uuid NOT NULL REFERENCES activity.activities(id) ON DELETE CASCADE,
    media_type  varchar(10) NOT NULL CHECK (media_type IN ('image','video','audio','pdf')),
    url         text NOT NULL,
    thumbnail_url text,
    duration_seconds int,
    caption     varchar(300),
    sort_order  smallint NOT NULL DEFAULT 0
);
CREATE INDEX ON activity.activity_media (activity_id, sort_order);

-- Ho?t d?ng y�u th�ch c?a ph? huynh (m�n danh s�ch y�u th�ch)
CREATE TABLE activity.activity_favorites (
    user_id     uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    activity_id uuid NOT NULL REFERENCES activity.activities(id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, activity_id)
);
CREATE INDEX ON activity.activity_favorites (user_id, created_at DESC);

-- Tr?ng th�i "�� l�m" theo T?NG TR? (kh�c y�u th�ch: y�u th�ch theo ph? huynh)
CREATE TABLE activity.child_activity_progress (
    child_id     uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    activity_id  uuid NOT NULL REFERENCES activity.activities(id) ON DELETE CASCADE,
    status       varchar(15) NOT NULL DEFAULT 'done' CHECK (status IN ('in_progress','done')),
    completed_at timestamptz,
    note         text,
    updated_by   uuid REFERENCES account.users(id),   -- ai d�nh d?u (caregiver cung c� th?)
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (child_id, activity_id),
    CHECK ((status = 'done') = (completed_at IS NOT NULL))
);
CREATE INDEX ON activity.child_activity_progress (child_id, completed_at DESC);

-- ---------------------------------------------------------------------
-- F07 � Nh?t k� ph�t tri?n
-- ---------------------------------------------------------------------
CREATE TABLE diary.diary_entries (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id    uuid NOT NULL REFERENCES child.children(id) ON DELETE CASCADE,
    author_id   uuid NOT NULL REFERENCES account.users(id),
    title       varchar(200),
    content     text,
    entry_date  date NOT NULL DEFAULT current_date,
    mood        varchar(20),
    tags        text[],
    updated_by  uuid REFERENCES account.users(id),
    deleted_by  uuid REFERENCES account.users(id),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    deleted_at  timestamptz                          -- x�a m?m (F07.3)
);
CREATE INDEX ON diary.diary_entries (child_id, entry_date DESC) WHERE deleted_at IS NULL;  -- l?c theo th?i gian (F07.2)

-- M?t b�i nh?t k� thu?c nhi?u linh v?c (nhi?u-nhi?u)
CREATE TABLE diary.diary_entry_domains (
    entry_id  uuid NOT NULL REFERENCES diary.diary_entries(id) ON DELETE CASCADE,
    domain_id int  NOT NULL REFERENCES criteria.developmental_domains(id),
    PRIMARY KEY (entry_id, domain_id)
);
CREATE INDEX ON diary.diary_entry_domains (domain_id, entry_id);

CREATE TABLE diary.diary_media (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id    uuid NOT NULL REFERENCES diary.diary_entries(id) ON DELETE CASCADE,
    media_type  varchar(10) NOT NULL CHECK (media_type IN ('image','video')),
    url         text NOT NULL,
    sort_order  smallint NOT NULL DEFAULT 0
);

-- ---------------------------------------------------------------------
-- F08 / F17 � Th�ng b�o & nh?c l?ch
-- ---------------------------------------------------------------------
CREATE TABLE notification.notification_types (
    id              serial PRIMARY KEY,
    code            varchar(40) NOT NULL UNIQUE,    -- assessment_reminder, growth_reminder, vaccine_reminder, system, share_invite...
    name            varchar(100) NOT NULL,
    trigger_event   varchar(50),
    is_enabled      boolean NOT NULL DEFAULT true,
    default_channel varchar(10) NOT NULL DEFAULT 'push' CHECK (default_channel IN ('push','in_app','email'))
);

CREATE TABLE notification.notification_templates (
    id          serial PRIMARY KEY,
    type_id     int NOT NULL REFERENCES notification.notification_types(id) ON DELETE CASCADE,
    language    varchar(5) NOT NULL DEFAULT 'vi',
    title       varchar(200) NOT NULL,
    body        text NOT NULL,                      -- h? tr? placeholder {{child_name}}, {{date}}...
    UNIQUE (type_id, language)
);

CREATE TABLE notification.reminder_rules (                   -- c?u h�nh th?i di?m g?i (F17.2)
    id            serial PRIMARY KEY,
    type_id       int NOT NULL REFERENCES notification.notification_types(id) ON DELETE CASCADE,
    days_before   smallint NOT NULL DEFAULT 0,
    send_time     time NOT NULL DEFAULT '08:00',
    repeat_every_days smallint,
    is_active     boolean NOT NULL DEFAULT true
);

CREATE TABLE notification.user_notification_settings (
    user_id     uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    type_id     int  NOT NULL REFERENCES notification.notification_types(id) ON DELETE CASCADE,
    is_enabled  boolean NOT NULL DEFAULT true,
    PRIMARY KEY (user_id, type_id)
);

-- L?ch nh?c c? th? sinh ra cho t?ng tr? (job qu�t b?ng n�y d? g?i)
CREATE TABLE notification.reminders (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id      uuid REFERENCES child.children(id) ON DELETE CASCADE,
    user_id       uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    type_id       int NOT NULL REFERENCES notification.notification_types(id),
    ref_type      varchar(30),                      -- vaccination / assessment / growth
    ref_id        text,
    remind_at     timestamptz NOT NULL,
    status        varchar(15) NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled','sent','cancelled','done')),
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON notification.reminders (status, remind_at);

CREATE TABLE notification.notifications (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    type_id       int REFERENCES notification.notification_types(id),
    reminder_id   uuid REFERENCES notification.reminders(id) ON DELETE SET NULL,
    title         varchar(200) NOT NULL,
    body          text NOT NULL,
    target_type   varchar(30),                      -- d? di?u hu?ng (F08.5): growth, assessment, vaccination, activity, invitation...
    target_id     text,
    data          jsonb,
    read_at       timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON notification.notifications (user_id, created_at DESC);

CREATE TABLE notification.notification_delivery_logs (       -- F17.4
    id               bigserial PRIMARY KEY,
    notification_id  uuid NOT NULL REFERENCES notification.notifications(id) ON DELETE CASCADE,
    device_token_id  uuid REFERENCES account.device_tokens(id) ON DELETE SET NULL,
    channel          varchar(10) NOT NULL,
    status           varchar(15) NOT NULL CHECK (status IN ('queued','sent','failed','delivered')),
    provider_message_id text,
    error_message    text,
    sent_at          timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- F21 / F22 � C?ng d?ng & ki?m duy?t (Option)
-- ---------------------------------------------------------------------
CREATE TABLE community.posts (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id   uuid NOT NULL REFERENCES account.users(id),
    content     text NOT NULL,
    status      varchar(15) NOT NULL DEFAULT 'published' CHECK (status IN ('published','hidden','removed')),
    like_count  int NOT NULL DEFAULT 0,
    comment_count int NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON community.posts (status, created_at DESC);

CREATE TABLE community.post_media (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id    uuid NOT NULL REFERENCES community.posts(id) ON DELETE CASCADE,
    media_type varchar(10) NOT NULL CHECK (media_type IN ('image','video')),
    url        text NOT NULL,
    sort_order smallint NOT NULL DEFAULT 0
);

CREATE TABLE community.post_comments (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id    uuid NOT NULL REFERENCES community.posts(id) ON DELETE CASCADE,
    author_id  uuid NOT NULL REFERENCES account.users(id),
    parent_id  uuid REFERENCES community.post_comments(id) ON DELETE CASCADE,
    content    text NOT NULL,
    status     varchar(15) NOT NULL DEFAULT 'published' CHECK (status IN ('published','hidden','removed')),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON community.post_comments (post_id, created_at);

CREATE TABLE community.post_likes (
    post_id    uuid NOT NULL REFERENCES community.posts(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

-- B�i vi?t d� luu (kh�c th�ch)
CREATE TABLE community.post_saves (
    post_id    uuid NOT NULL REFERENCES community.posts(id) ON DELETE CASCADE,
    user_id    uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);
CREATE INDEX ON community.post_saves (user_id, created_at DESC);

CREATE TABLE community.content_reports (                  -- F21.4
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id   uuid NOT NULL REFERENCES account.users(id),
    target_type   varchar(10) NOT NULL CHECK (target_type IN ('post','comment')),
    target_id     uuid NOT NULL,
    reason        varchar(30) NOT NULL,
    detail        text,
    status        varchar(15) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','resolved','dismissed')),
    handled_by    uuid REFERENCES admin.admin_users(id),
    handled_at    timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (reporter_id, target_type, target_id)
);
CREATE INDEX ON community.content_reports (status, created_at);

CREATE TABLE community.moderation_actions (               -- F22.2, F22.3
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id     uuid REFERENCES community.content_reports(id) ON DELETE SET NULL,
    admin_user_id uuid NOT NULL REFERENCES admin.admin_users(id),
    target_type   varchar(10) NOT NULL,
    target_id     uuid NOT NULL,
    action        varchar(20) NOT NULL CHECK (action IN ('hide','remove','restore','warn_user','lock_user','dismiss')),
    note          text,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- F19 � Th?ng k� (g?i �: materialized view/ b?ng t?ng h?p theo ng�y)
-- ---------------------------------------------------------------------
CREATE TABLE report.daily_stats (
    stat_date            date PRIMARY KEY,
    new_users            int NOT NULL DEFAULT 0,
    active_users         int NOT NULL DEFAULT 0,
    new_children         int NOT NULL DEFAULT 0,
    assessments_started  int NOT NULL DEFAULT 0,
    assessments_completed int NOT NULL DEFAULT 0,
    chat_sessions        int NOT NULL DEFAULT 0,
    chat_messages        int NOT NULL DEFAULT 0,
    created_at           timestamptz NOT NULL DEFAULT now()
);

-- =====================================================================

