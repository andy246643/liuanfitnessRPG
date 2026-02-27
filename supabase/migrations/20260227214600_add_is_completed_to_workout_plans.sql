-- 新增 is_completed 欄位到 workout_plans，預設為 false，用來取代之前的 hard delete
ALTER TABLE public.workout_plans ADD COLUMN is_completed BOOLEAN NOT NULL DEFAULT FALSE;
