CREATE TABLE IF NOT EXISTS public.professional_live_locations (
  professional_id text PRIMARY KEY,
  request_id text,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  heading double precision,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.professional_live_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS nee_live_loc_select ON public.professional_live_locations;
CREATE POLICY nee_live_loc_select ON public.professional_live_locations
  FOR SELECT TO authenticated
  USING (
    professional_id = auth.uid()::text
    OR EXISTS (
      SELECT 1 FROM public.service_requests r
      WHERE r.client_id = auth.uid()::text
        AND COALESCE(
          r.selected_professional_id,
          r.profissional_id,
          r.target_professional_id
        ) = professional_id
    )
  );

DROP POLICY IF EXISTS nee_live_loc_upsert ON public.professional_live_locations;
CREATE POLICY nee_live_loc_upsert ON public.professional_live_locations
  FOR INSERT TO authenticated
  WITH CHECK (professional_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_live_loc_update ON public.professional_live_locations;
CREATE POLICY nee_live_loc_update ON public.professional_live_locations
  FOR UPDATE TO authenticated
  USING (professional_id = auth.uid()::text)
  WITH CHECK (professional_id = auth.uid()::text);

GRANT SELECT, INSERT, UPDATE ON public.professional_live_locations TO authenticated;

CREATE OR REPLACE FUNCTION public.upsert_professional_live_location(
  p_latitude double precision,
  p_longitude double precision,
  p_request_id text DEFAULT NULL,
  p_heading double precision DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  INSERT INTO public.professional_live_locations (
    professional_id, request_id, latitude, longitude, heading, updated_at
  ) VALUES (uid, p_request_id, p_latitude, p_longitude, p_heading, now())
  ON CONFLICT (professional_id) DO UPDATE
    SET request_id = COALESCE(EXCLUDED.request_id, public.professional_live_locations.request_id),
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        heading = EXCLUDED.heading,
        updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_professional_live_location(double precision, double precision, text, double precision) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_professional_live_location(double precision, double precision, text, double precision) TO authenticated;

ALTER TABLE public.professional_live_locations REPLICA IDENTITY FULL;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.professional_live_locations;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
