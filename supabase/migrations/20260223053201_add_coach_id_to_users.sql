ALTER TABLE public.users ADD COLUMN IF NOT EXISTS coach_id UUID REFERENCES public.users(id);
