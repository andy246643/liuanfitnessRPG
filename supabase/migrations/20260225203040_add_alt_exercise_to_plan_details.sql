-- Add alternative exercise fields to plan_details
ALTER TABLE public.plan_details 
ADD COLUMN IF NOT EXISTS alt_exercise TEXT,
ADD COLUMN IF NOT EXISTS alt_target_weight NUMERIC NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS alt_target_sets INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS alt_target_reps INTEGER NOT NULL DEFAULT 0;
