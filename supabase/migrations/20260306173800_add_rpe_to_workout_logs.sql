-- 新增 rpe 欄位到 workout_logs，用以記錄整份課表完成後的疲勞度
ALTER TABLE public.workout_logs ADD COLUMN IF NOT EXISTS rpe INTEGER;
