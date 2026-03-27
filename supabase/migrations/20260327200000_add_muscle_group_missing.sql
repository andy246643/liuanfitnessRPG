-- Re-apply: add muscle_group to plan_details (previous migration was tracked
-- but the column was never actually created in the remote DB).
ALTER TABLE public.plan_details ADD COLUMN IF NOT EXISTS muscle_group TEXT;
