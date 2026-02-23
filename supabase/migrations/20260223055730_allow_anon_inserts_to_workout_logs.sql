-- 允許 anon 角色的任何使用者在 workout_logs 新增資料
-- (為了配合目前 Fitness RPG App 未登入狀態下的機制)
CREATE POLICY "Allow anon insert to workout_logs"
ON public.workout_logs
FOR INSERT
TO anon
WITH CHECK (true);
