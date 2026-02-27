-- 1. 建立 users (學員/使用者表)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY, -- 通常對應 auth.users(id)
  name TEXT NOT NULL,
  role TEXT DEFAULT 'trainee',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. 建立 workout_plans (父表)
CREATE TABLE IF NOT EXISTS public.workout_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_name TEXT NOT NULL,
  user_id UUID NOT NULL, 
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. 建立 plan_details (子表)
CREATE TABLE IF NOT EXISTS public.plan_details (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES public.workout_plans(id) ON DELETE CASCADE,
  exercise TEXT NOT NULL,
  target_weight NUMERIC NOT NULL DEFAULT 0,
  target_sets INTEGER NOT NULL DEFAULT 0,
  target_reps INTEGER NOT NULL DEFAULT 0,
  target_rpe INTEGER NOT NULL DEFAULT 0,
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- (選擇性) 如果您要確保 workout_plans 有關聯到 users，可以執行以下 ALTER TABLE。
-- 注意：如果您的 workout_plans 目前有假資料，且裡面的 user_id 在 users 找不到，執行這行會報錯！
-- ALTER TABLE public.workout_plans ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 4. 如果您有在使用 RLS (Row Level Security)，別忘了開啟它們並設定 Policy
-- ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.workout_plans ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.plan_details ENABLE ROW LEVEL SECURITY;

-- 5. 新增：為課表詳細動作加上教練指派的「休息時間 (秒)」
-- ALTER TABLE public.plan_details ADD COLUMN rest_time_seconds INTEGER NOT NULL DEFAULT 60;
