-- Simulation state: iOS writes current view context when play is tapped.
-- Claude reads this to know which document/question/step the user is on.

CREATE TABLE IF NOT EXISTS simulation_state (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    question_label TEXT NOT NULL DEFAULT 'Q1a',
    step_index INT NOT NULL DEFAULT 0,
    total_steps INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE simulation_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own simulation_state"
    ON simulation_state FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on simulation_state"
    ON simulation_state FOR ALL
    USING (auth.role() = 'service_role');
