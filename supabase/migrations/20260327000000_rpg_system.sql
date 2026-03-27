-- RPG System: Energy Logs & Character Progression
-- 2026-03-27

-- 能量紀錄表
CREATE TABLE IF NOT EXISTS energy_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) NOT NULL,
  session_id UUID,
  energy_earned INTEGER NOT NULL DEFAULT 0,
  source TEXT NOT NULL DEFAULT 'workout',
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RPG 角色表
CREATE TABLE IF NOT EXISTS rpg_characters (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) NOT NULL UNIQUE,
  name TEXT NOT NULL DEFAULT '冒險者',
  level INTEGER NOT NULL DEFAULT 1,
  total_exp INTEGER NOT NULL DEFAULT 0,
  current_energy INTEGER NOT NULL DEFAULT 0,
  attr_chest INTEGER NOT NULL DEFAULT 0,
  attr_back INTEGER NOT NULL DEFAULT 0,
  attr_legs INTEGER NOT NULL DEFAULT 0,
  attr_arms INTEGER NOT NULL DEFAULT 0,
  attr_core INTEGER NOT NULL DEFAULT 0,
  attr_cardio INTEGER NOT NULL DEFAULT 0,
  streak_days INTEGER NOT NULL DEFAULT 0,
  last_training_date DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- plan_details 加入次要肌群欄位
ALTER TABLE plan_details ADD COLUMN IF NOT EXISTS secondary_muscle_group TEXT;

-- RLS policies (anon access for now, matching existing pattern)
ALTER TABLE energy_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE rpg_characters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon insert energy_logs" ON energy_logs FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon select energy_logs" ON energy_logs FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert rpg_characters" ON rpg_characters FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon select rpg_characters" ON rpg_characters FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon update rpg_characters" ON rpg_characters FOR UPDATE TO anon USING (true) WITH CHECK (true);
