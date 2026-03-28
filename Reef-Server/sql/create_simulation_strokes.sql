-- Simulation strokes: Claude writes, iOS subscribes via Supabase Realtime.

CREATE TABLE IF NOT EXISTS simulation_strokes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id TEXT NOT NULL,
    question_label TEXT NOT NULL DEFAULT 'Q1a',
    strokes JSONB NOT NULL,
    latex TEXT NOT NULL DEFAULT '',
    origin_x FLOAT NOT NULL DEFAULT 30,
    origin_y FLOAT NOT NULL DEFAULT 150,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE simulation_strokes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own simulation_strokes"
    ON simulation_strokes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role full access on simulation_strokes"
    ON simulation_strokes FOR ALL
    USING (auth.role() = 'service_role');

-- Enable realtime for this table
ALTER PUBLICATION supabase_realtime ADD TABLE simulation_strokes;
