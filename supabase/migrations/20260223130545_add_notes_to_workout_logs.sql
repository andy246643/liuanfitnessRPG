-- Add notes column to workout_logs
ALTER TABLE public.workout_logs ADD COLUMN IF NOT EXISTS notes TEXT;
