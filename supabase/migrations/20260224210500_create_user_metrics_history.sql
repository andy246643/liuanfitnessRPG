CREATE TABLE IF NOT EXISTS public.user_metrics_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  weight NUMERIC,
  body_fat NUMERIC,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS if needed, although we are using anon key, let's keep it simple for now as everything is currently accessible.
-- ALTER TABLE public.user_metrics_history ENABLE ROW LEVEL SECURITY;
