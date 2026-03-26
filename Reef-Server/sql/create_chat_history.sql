-- Chat history: server writes after each eval/chat response.
-- One row per message. Server reads the last 15 for context.

CREATE TABLE IF NOT EXISTS chat_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    question_label TEXT NOT NULL,
    role TEXT NOT NULL,  -- 'student', 'error', 'reinforcement', 'answer', 'confidenceCheck'
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_history_lookup
    ON chat_history (user_id, document_id, question_label, created_at);

ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own chat_history"
    ON chat_history FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on chat_history"
    ON chat_history FOR ALL
    USING (auth.role() = 'service_role');
