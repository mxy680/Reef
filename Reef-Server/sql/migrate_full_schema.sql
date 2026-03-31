-- Full Reef schema migration
-- Generated for migration to new Supabase project

-- ============================================================
-- PROFILES (extends auth.users)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    grade TEXT,
    subjects JSONB,
    onboarding_completed BOOLEAN DEFAULT false,
    referral_source TEXT,
    settings JSONB,
    referral_code TEXT,
    referred_by TEXT,
    major TEXT,
    study_goal TEXT,
    pain_points TEXT[],
    learning_style TEXT,
    favorite_topic TEXT
);
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own profile" ON profiles FOR ALL
    USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Service role full access on profiles" ON profiles FOR ALL
    USING (auth.role() = 'service_role');

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- COURSES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own courses" ON courses FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on courses" ON courses FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- DOCUMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.documents (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    page_count INT,
    problem_count INT,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    status_message TEXT,
    input_tokens INT DEFAULT 0,
    output_tokens INT DEFAULT 0,
    llm_calls INT DEFAULT 0,
    gpu_seconds DOUBLE PRECISION DEFAULT 0,
    pipeline_seconds DOUBLE PRECISION DEFAULT 0,
    cost_cents INT DEFAULT 0,
    question_pages JSONB,
    question_regions JSONB
);
CREATE INDEX IF NOT EXISTS idx_documents_user ON documents (user_id);
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own documents" ON documents FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on documents" ON documents FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- ANSWER KEYS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.answer_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    question_number INT NOT NULL,
    question_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    answer_text TEXT NOT NULL DEFAULT '',
    model TEXT,
    input_tokens INT DEFAULT 0,
    output_tokens INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (document_id, question_number)
);
CREATE INDEX IF NOT EXISTS idx_answer_keys_doc ON answer_keys (document_id);
ALTER TABLE answer_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own answer keys" ON answer_keys FOR SELECT
    USING (EXISTS (SELECT 1 FROM documents d WHERE d.id = answer_keys.document_id AND d.user_id = auth.uid()));
CREATE POLICY "Service role full access on answer_keys" ON answer_keys FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- CANVAS STROKES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.canvas_strokes (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    question_label TEXT NOT NULL,
    page_index INT NOT NULL DEFAULT 0,
    strokes JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    latex TEXT,
    tutor_progress DOUBLE PRECISION,
    tutor_status TEXT,
    tutor_step INT,
    tutor_steps_completed INT,
    tutor_speech_text TEXT,
    transcription_chunks JSONB,
    PRIMARY KEY (user_id, document_id, question_label)
);
CREATE INDEX IF NOT EXISTS idx_canvas_strokes_lookup
    ON canvas_strokes (user_id, document_id, question_label);
CREATE INDEX IF NOT EXISTS idx_canvas_strokes_updated
    ON canvas_strokes (user_id, document_id, updated_at DESC);
ALTER TABLE canvas_strokes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own canvas strokes" ON canvas_strokes FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on canvas_strokes" ON canvas_strokes FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- CHAT HISTORY
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chat_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    question_label TEXT NOT NULL,
    role TEXT NOT NULL,
    text TEXT NOT NULL,
    speech_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_chat_history_lookup
    ON chat_history (user_id, document_id, question_label);
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own chat history" ON chat_history FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on chat_history" ON chat_history FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- STUDENT WORK
-- ============================================================
CREATE TABLE IF NOT EXISTS public.student_work (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    question_label TEXT NOT NULL,
    latex_display TEXT NOT NULL DEFAULT '',
    latex_raw TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, document_id, question_label)
);
CREATE INDEX IF NOT EXISTS idx_student_work_lookup
    ON student_work (document_id, question_label);
ALTER TABLE student_work ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own student_work" ON student_work FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on student_work" ON student_work FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- CONCEPT STRUGGLES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.concept_struggles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    concept TEXT NOT NULL,
    question_number INT NOT NULL,
    step_index INT NOT NULL DEFAULT 0,
    part_label TEXT,
    mistake_count INT NOT NULL DEFAULT 1,
    resolved BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_concept_struggles_lookup
    ON concept_struggles (user_id, document_id, concept);
ALTER TABLE concept_struggles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own concept struggles" ON concept_struggles FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on concept_struggles" ON concept_struggles FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- API COSTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.api_costs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    feature TEXT NOT NULL,
    provider TEXT NOT NULL DEFAULT '',
    model TEXT NOT NULL DEFAULT '',
    input_tokens INT NOT NULL DEFAULT 0,
    output_tokens INT NOT NULL DEFAULT 0,
    cost_dollars DOUBLE PRECISION NOT NULL DEFAULT 0,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_api_costs_user ON api_costs (user_id, feature);
ALTER TABLE api_costs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access on api_costs" ON api_costs FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- USER COST SUMMARY (materialized view or table)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_cost_summary (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    feature TEXT NOT NULL,
    provider TEXT NOT NULL DEFAULT '',
    call_count INT NOT NULL DEFAULT 0,
    total_input_tokens BIGINT NOT NULL DEFAULT 0,
    total_output_tokens BIGINT NOT NULL DEFAULT 0,
    total_cost_dollars DOUBLE PRECISION NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, feature, provider)
);
ALTER TABLE user_cost_summary ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role full access on user_cost_summary" ON user_cost_summary FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- TTS CACHE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.tts_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cache_key TEXT UNIQUE NOT NULL,
    text_input TEXT NOT NULL,
    audio_base64 TEXT NOT NULL,
    voice TEXT,
    model TEXT,
    speed DOUBLE PRECISION DEFAULT 1.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tts_cache_key ON tts_cache (cache_key);

-- ============================================================
-- CONFIDENCE LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.confidence_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    question_number INT NOT NULL,
    step_index INT NOT NULL DEFAULT 0,
    confidence INT NOT NULL,
    had_mistake BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE confidence_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own confidence logs" ON confidence_logs FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role full access on confidence_logs" ON confidence_logs FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- BUG REPORTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.bug_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    email TEXT,
    message TEXT NOT NULL,
    device_info JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE bug_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can insert bug reports" ON bug_reports FOR INSERT
    WITH CHECK (true);
CREATE POLICY "Service role full access on bug_reports" ON bug_reports FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================
-- SIMULATION STATE (DEBUG)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.simulation_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    question_number INT NOT NULL,
    part_label TEXT,
    personality TEXT DEFAULT 'mistake_prone',
    current_step INT DEFAULT 0,
    status TEXT DEFAULT 'active',
    session_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- SIMULATION STROKES (DEBUG)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.simulation_strokes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    question_label TEXT NOT NULL,
    strokes JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- NEWSLETTER SUBSCRIBERS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.newsletter_subscribers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('figures', 'figures', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
CREATE POLICY "Users upload own documents" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users read own documents" ON storage.objects FOR SELECT
    USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Service role manages all storage" ON storage.objects FOR ALL
    USING (auth.role() = 'service_role');
