-- Add settings JSONB column to profiles table
-- Stores all user preferences and privacy settings as a single JSON blob.
-- Every key has a default in the iOS UserSettings struct, so partial/empty JSON is fine.
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS settings JSONB NOT NULL DEFAULT '{}'::jsonb;
