-- Ensure canvas_strokes has a composite index for the polling and eval queries.
-- The iOS app polls this table every 1-3 seconds per user.
CREATE INDEX IF NOT EXISTS idx_canvas_strokes_lookup
    ON canvas_strokes (user_id, document_id, question_label);

CREATE INDEX IF NOT EXISTS idx_canvas_strokes_updated
    ON canvas_strokes (user_id, document_id, updated_at DESC);
