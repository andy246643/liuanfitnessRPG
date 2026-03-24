-- 新增肌群分類欄位，讓教練可以手動標註動作的肌群
ALTER TABLE public.plan_details ADD COLUMN IF NOT EXISTS muscle_group TEXT;
