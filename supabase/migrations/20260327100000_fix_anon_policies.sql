-- Fix: ensure anon role has full CRUD access on workout_plans and plan_details.
-- These tables have no explicit RLS policies for UPDATE/DELETE, which causes
-- the coach app's plan-edit save to fail with a policy violation.
-- Pattern: enable RLS + grant full anon access (matching existing tables).

-- workout_plans
ALTER TABLE public.workout_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anon all on workout_plans" ON public.workout_plans;
CREATE POLICY "Allow anon all on workout_plans"
  ON public.workout_plans FOR ALL TO anon
  USING (true) WITH CHECK (true);

-- plan_details
ALTER TABLE public.plan_details ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anon all on plan_details" ON public.plan_details;
CREATE POLICY "Allow anon all on plan_details"
  ON public.plan_details FOR ALL TO anon
  USING (true) WITH CHECK (true);
