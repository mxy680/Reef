-- Per-user API cost tracking: append-only ledger of every API call cost.

CREATE TABLE IF NOT EXISTS api_costs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    feature TEXT NOT NULL,       -- 'reconstruct', 'answer_key', 'tutor_eval', 'tutor_chat', 'transcribe', 'tts', 'demo'
    provider TEXT NOT NULL,      -- 'openrouter', 'mathpix_pdf', 'mathpix_strokes', 'elevenlabs', 'groq'
    model TEXT,                  -- e.g. 'google/gemini-3-flash-preview'
    input_tokens INT DEFAULT 0,
    output_tokens INT DEFAULT 0,
    cost_dollars NUMERIC(10,6) NOT NULL DEFAULT 0,
    metadata JSONB,              -- document_id, question_number, stage, etc.
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_api_costs_user_date ON api_costs(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_api_costs_user_feature ON api_costs(user_id, feature);

-- Aggregation view for dashboard queries
CREATE OR REPLACE VIEW user_cost_summary AS
SELECT
    user_id,
    feature,
    provider,
    count(*) as call_count,
    sum(input_tokens) as total_input_tokens,
    sum(output_tokens) as total_output_tokens,
    sum(cost_dollars) as total_cost_dollars
FROM api_costs
GROUP BY user_id, feature, provider;

-- RLS
ALTER TABLE api_costs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own costs"
    ON api_costs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role full access"
    ON api_costs FOR ALL
    USING (auth.role() = 'service_role');
