-- TRACK CHILDREN AI DATABASE
-- 3 schema: ai_kb, ai_chatbot, ai_analysis
-- Chạy file này trong database track_children_ai.
-- Các ID tham chiếu Backend chỉ là UUID/ID; xác thực qua Backend API.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS common;
CREATE SCHEMA IF NOT EXISTS ai_kb;
CREATE SCHEMA IF NOT EXISTS ai_chatbot;
CREATE SCHEMA IF NOT EXISTS ai_analysis;

CREATE OR REPLACE FUNCTION common.set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

-- F14.1 � T�i li?u co s? tri th?c
CREATE TABLE IF NOT EXISTS ai_kb.kb_documents (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title         varchar(300) NOT NULL,
    source_id     uuid,
    file_url      text,
    file_type     varchar(10) CHECK (file_type IN ('pdf','docx','txt','md','html')),
    file_checksum varchar(64),
    language      varchar(5) NOT NULL DEFAULT 'vi',
    category      varchar(50),                      -- development, nutrition, vaccination, home_support...
    version       int NOT NULL DEFAULT 1,
    status        varchar(15) NOT NULL DEFAULT 'uploaded'
                  CHECK (status IN ('uploaded','processing','indexed','failed','archived')),
    is_active     boolean NOT NULL DEFAULT true,    -- chatbot ch? truy xu?t t�i li?u active
    uploaded_by   uuid,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

-- F14.2 � Chunk + embedding (d?i s? chi?u theo model embedding, vd 768 / 1024 / 1536)
CREATE TABLE IF NOT EXISTS ai_kb.kb_chunks (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id   uuid NOT NULL REFERENCES ai_kb.kb_documents(id) ON DELETE CASCADE,
    chunk_index   int NOT NULL,
    content       text NOT NULL,
    token_count   int,
    page_number   int,
    section_title varchar(300),
    metadata      jsonb NOT NULL DEFAULT '{}'::jsonb,   -- age_range, domain...
    embedding     vector(1024),
    content_tsv   tsvector GENERATED ALWAYS AS (to_tsvector('simple', content)) STORED,  -- hybrid search
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (document_id, chunk_index)
);
CREATE INDEX IF NOT EXISTS kb_chunks_embedding_idx ON ai_kb.kb_chunks USING hnsw (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS kb_chunks_tsv_idx ON ai_kb.kb_chunks USING gin (content_tsv);

CREATE TABLE IF NOT EXISTS ai_kb.kb_index_jobs (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id   uuid NOT NULL REFERENCES ai_kb.kb_documents(id) ON DELETE CASCADE,
    job_type      varchar(15) NOT NULL CHECK (job_type IN ('index','reindex','delete')),
    status        varchar(15) NOT NULL DEFAULT 'queued'
                  CHECK (status IN ('queued','running','succeeded','failed')),
    embedding_model varchar(100),
    chunk_size    int,
    chunk_overlap int,
    chunks_created int,
    error_message text,
    started_at    timestamptz,
    finished_at   timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- F14.3 / F14.4 � [Option] Candidate Criteria do LLM tr�ch xu?t & ki?m duy?t
CREATE TABLE IF NOT EXISTS ai_kb.candidate_criteria (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id   uuid NOT NULL REFERENCES ai_kb.kb_documents(id) ON DELETE CASCADE,
    chunk_id      uuid REFERENCES ai_kb.kb_chunks(id) ON DELETE SET NULL,
    domain_id     int,
    milestone_id  int,
    title         varchar(300) NOT NULL,
    description   text,
    suggested_questions jsonb,                      -- ["B� c� ... kh�ng?", ...]
    source_excerpt text,
    llm_model     varchar(100),
    confidence    numeric(4,3),
    status        varchar(15) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','approved','rejected','merged')),
    reviewed_by   uuid,
    reviewed_at   timestamptz,
    review_note   text,
    promoted_criterion_id uuid,   -- ti�u ch� ch�nh th?c du?c t?o ra
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS candidate_criteria_status_idx ON ai_kb.candidate_criteria (status);

-- F10 � H?i tho?i chatbot
CREATE TABLE IF NOT EXISTS ai_chatbot.chat_conversations (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL,
    child_id    uuid,   -- ngữ cảnh trẻ (F10.4)
    title       varchar(200),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    deleted_at  timestamptz
);
CREATE INDEX IF NOT EXISTS chat_conversations_user_updated_idx
    ON ai_chatbot.chat_conversations (user_id, updated_at DESC) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS ai_chatbot.chat_messages (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid NOT NULL REFERENCES ai_chatbot.chat_conversations(id) ON DELETE CASCADE,
    role            varchar(10) NOT NULL CHECK (role IN ('user','assistant','system')),
    content         text NOT NULL,
    intent          varchar(30),                    -- knowledge / milestone / home_support / assessment_result / out_of_scope
    has_source      boolean,
    feedback        smallint CHECK (feedback IN (-1,1)),   -- thumbs down / up
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS chat_messages_conversation_created_idx
    ON ai_chatbot.chat_messages (conversation_id, created_at);

-- Ngu?n tr�ch d?n c?a c�u tr? l?i (RAG citations)
CREATE TABLE IF NOT EXISTS ai_chatbot.chat_message_sources (
    message_id  uuid NOT NULL REFERENCES ai_chatbot.chat_messages(id) ON DELETE CASCADE,
    chunk_id    uuid NOT NULL REFERENCES ai_kb.kb_chunks(id) ON DELETE CASCADE,
    rank        smallint NOT NULL,
    score       numeric(6,4),
    PRIMARY KEY (message_id, chunk_id)
);

-- F18.1 / F18.3 � Log tuong t�c & hi?u nang
CREATE TABLE IF NOT EXISTS ai_chatbot.chat_request_logs (
    id                 bigserial PRIMARY KEY,
    message_id         uuid REFERENCES ai_chatbot.chat_messages(id) ON DELETE SET NULL,   -- tin nh?n tr? l?i
    conversation_id    uuid REFERENCES ai_chatbot.chat_conversations(id) ON DELETE SET NULL,
    user_id            uuid,
    query_text         text,
    rewritten_query    text,
    llm_model          varchar(100),
    embedding_model    varchar(100),
    prompt_version     varchar(20),
    retrieved_chunks   smallint,
    top_score          numeric(6,4),
    prompt_tokens      int,
    completion_tokens  int,
    retrieval_ms       int,
    llm_ms             int,
    total_ms           int,
    status             varchar(15) NOT NULL DEFAULT 'success' CHECK (status IN ('success','error','timeout','blocked')),
    error_message      text,
    created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS chat_request_logs_created_idx
    ON ai_chatbot.chat_request_logs (created_at);

-- F18.2 � C�u h?i kh�ng c� ngu?n ph� h?p
CREATE TABLE IF NOT EXISTS ai_chatbot.unanswered_questions (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id    uuid REFERENCES ai_chatbot.chat_messages(id) ON DELETE SET NULL,
    question_text text NOT NULL,
    reason        varchar(30) NOT NULL DEFAULT 'no_relevant_source'
                  CHECK (reason IN ('no_relevant_source','low_score','out_of_scope','safety_blocked')),
    top_score     numeric(6,4),
    status        varchar(15) NOT NULL DEFAULT 'new' CHECK (status IN ('new','reviewed','kb_updated','ignored')),
    handled_by    uuid,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- F06 / F15.2 � Log ph�n t�ch k?t qu? d�nh gi� b?ng AI
CREATE TABLE IF NOT EXISTS ai_analysis.analysis_logs (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assessment_id    uuid NOT NULL,
    child_id         uuid NOT NULL,
    reference_version_id uuid,
    llm_model        varchar(100),
    prompt_version   varchar(20),
    input_payload    jsonb NOT NULL,                -- c�u tr? l?i + tu?i + ch? s? tang tru?ng (d� ?n danh)
    output_payload   jsonb,
    used_chunk_ids   uuid[],
    latency_ms       int,
    prompt_tokens    int,
    completion_tokens int,
    status           varchar(15) NOT NULL DEFAULT 'success' CHECK (status IN ('success','error','timeout')),
    error_message    text,
    created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS analysis_logs_assessment_idx
    ON ai_analysis.analysis_logs (assessment_id);

-- =====================================================================
-- G?n trigger updated_at cho m?i b?ng c� c?t updated_at
-- =====================================================================
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT table_schema, table_name FROM information_schema.columns
    WHERE column_name = 'updated_at' AND table_schema IN ('ai_kb','ai_chatbot','ai_analysis')
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.triggers
      WHERE trigger_schema = r.table_schema
        AND event_object_table = r.table_name
        AND trigger_name = format('trg_%s_updated_at', r.table_name)
    ) THEN
      EXECUTE format(
        'CREATE TRIGGER trg_%1$s_updated_at BEFORE UPDATE ON %2$I.%1$I
           FOR EACH ROW EXECUTE FUNCTION common.set_updated_at()',
        r.table_name, r.table_schema);
    END IF;
  END LOOP;
END $$;
