-- Migration: add prescribed_sets column to plan_details
-- Date: 2026-03-04

ALTER TABLE plan_details ADD COLUMN IF NOT EXISTS prescribed_sets JSONB DEFAULT '[]'::jsonb;

-- Example prescribed_sets value:
-- [{"weight": 30, "reps": 8}, {"weight": 50, "reps": 8}]
