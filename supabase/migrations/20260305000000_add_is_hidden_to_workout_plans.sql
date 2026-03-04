-- Migration to support soft-deleting workout plans for students
-- This ensures that when a student deletes a plan, it is only hidden from their view
-- but retained in the database for the coach to see.

ALTER TABLE workout_plans 
ADD COLUMN is_hidden BOOLEAN DEFAULT false;
