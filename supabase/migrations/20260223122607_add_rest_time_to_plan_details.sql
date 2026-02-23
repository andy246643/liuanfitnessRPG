-- 新增：為課表詳細動作加上教練指派的「休息時間 (秒)」
ALTER TABLE public.plan_details ADD COLUMN rest_time_seconds INTEGER NOT NULL DEFAULT 60;
