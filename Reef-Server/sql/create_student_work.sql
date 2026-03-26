-- Student work transcription: iOS writes, server reads.
-- One row per (user, document, question). Upserted on every transcription.

CREATE TABLE IF NOT EXISTS student_work (
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

CREATE POLICY "Users manage own student_work"
    ON student_work FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on student_work"
    ON student_work FOR ALL
    USING (auth.role() = 'service_role');
