-- Migration: add alt_prescribed_sets column to plan_details
-- Date: 2026-03-04

ALTER TABLE plan_details ADD COLUMN IF NOT EXISTS alt_prescribed_sets JSONB DEFAULT '[]'::jsonb;
