-- Migration: add warmup_sets column to plan_details
-- Date: 2026-03-02

ALTER TABLE plan_details ADD COLUMN IF NOT EXISTS warmup_sets JSONB DEFAULT '[]'::jsonb;

-- Example warmup_sets value:
-- [{"weight": 30, "reps": 8}, {"weight": 50, "reps": 8}]
