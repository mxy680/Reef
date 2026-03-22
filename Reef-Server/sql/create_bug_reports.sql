CREATE TABLE IF NOT EXISTS public.bug_reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    document_id text,
    question_label text,
    description text NOT NULL,
    created_at timestamptz DEFAULT now()
);

ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own bug reports"
    ON public.bug_reports FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on bug_reports"
    ON public.bug_reports FOR ALL
    USING (auth.role() = 'service_role');
