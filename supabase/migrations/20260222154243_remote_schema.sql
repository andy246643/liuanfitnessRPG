-- 1. 建立 users (學員/使用者表)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY, -- 通常對應 auth.users(id)
  name TEXT NOT NULL,
  role TEXT DEFAULT 'trainee',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 先刪除舊表 (因為結構改變很大，如果允許清空舊資料的話這是最快的作法)
DROP TABLE IF EXISTS public.plan_details CASCADE;
DROP TABLE IF EXISTS public.workout_plans CASCADE;

-- 2. 建立 workout_plans (父表)
CREATE TABLE public.workout_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_name TEXT NOT NULL,
  user_id TEXT NOT NULL, -- The user_id is currently text "liuan" in the DB. Let's make it TEXT first, or UUID if the auth.users is uuid. Wait, earlier data showed user_id: liuan. If users.id is UUID, maybe "liuan" was just a string. Let's use TEXT for user_id to avoid UUID parsing errors.
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. 建立 plan_details (子表)
CREATE TABLE public.plan_details (
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
