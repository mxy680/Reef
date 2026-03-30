-- Cross-question concept threading: tracks which concepts a student struggles with
-- so the tutor can reference prior struggles when the same concept appears later.

CREATE TABLE IF NOT EXISTS concept_struggles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    document_id TEXT NOT NULL,
    concept TEXT NOT NULL,
    question_number INT NOT NULL,
    step_index INT NOT NULL,
    part_label TEXT,
    status TEXT NOT NULL DEFAULT 'struggling' CHECK (status IN ('struggling', 'resolved')),
    mistake_count INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

-- Primary query: find all struggles for a user+document+concept+status
CREATE INDEX IF NOT EXISTS idx_concept_struggles_lookup
    ON concept_struggles(user_id, document_id, concept, status);

-- Prevent duplicate rows for the same user+document+concept+question+step
CREATE UNIQUE INDEX IF NOT EXISTS idx_concept_struggles_upsert
    ON concept_struggles(user_id, document_id, concept, question_number, step_index);

-- Row Level Security
ALTER TABLE concept_struggles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own struggles"
    ON concept_struggles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role full access"
    ON concept_struggles FOR ALL
    USING (auth.role() = 'service_role');
