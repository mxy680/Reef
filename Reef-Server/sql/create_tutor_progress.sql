-- Tutor progress persistence: stores step progress per user per document.
-- Run this in the Supabase SQL editor.

create table if not exists tutor_progress (
    user_id     uuid        not null references auth.users(id) on delete cascade,
    document_id text        not null,
    step_progress       jsonb not null default '{}',
    current_step_indices jsonb not null default '{}',
    updated_at  timestamptz not null default now(),
    primary key (user_id, document_id)
);

-- Auto-update updated_at on row change
create or replace function update_tutor_progress_timestamp()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger tutor_progress_updated_at
    before update on tutor_progress
    for each row
    execute function update_tutor_progress_timestamp();

-- RLS: users can only access their own progress
alter table tutor_progress enable row level security;

create policy "Users can select their own progress"
    on tutor_progress for select
    using (auth.uid() = user_id);

create policy "Users can insert their own progress"
    on tutor_progress for insert
    with check (auth.uid() = user_id);

create policy "Users can update their own progress"
    on tutor_progress for update
    using (auth.uid() = user_id);

create policy "Users can delete their own progress"
    on tutor_progress for delete
    using (auth.uid() = user_id);
