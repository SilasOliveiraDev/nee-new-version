-- Realtime de service_requests para o cliente ver NEGOTIATION sem reabrir o app.

ALTER TABLE public.service_requests REPLICA IDENTITY FULL;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.service_requests;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
