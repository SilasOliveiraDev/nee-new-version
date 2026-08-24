-- Cliente: ver profissionais destacados + persistir endereços salvos.

DROP POLICY IF EXISTS nee_users_select_featured ON public.users;
CREATE POLICY nee_users_select_featured ON public.users
  FOR SELECT TO authenticated
  USING (
    "UUID" = auth.uid()
    OR (
      "isDestacado" IS TRUE
      AND COALESCE("isDeletado", false) IS NOT TRUE
      AND COALESCE("isBloqueado", false) IS NOT TRUE
    )
  );

CREATE TABLE IF NOT EXISTS public.user_addresses (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid,
  type text NOT NULL,
  custom_label text,
  formatted_address text,
  street text,
  street_number text,
  neighborhood text,
  city text,
  state text,
  country text,
  country_code text,
  postal_code text,
  latitude double precision,
  longitude double precision,
  apartment text,
  floor text,
  reference text,
  place_id text,
  geocoding_provider text,
  location_accuracy double precision,
  is_default boolean DEFAULT false,
  is_location_confirmed boolean DEFAULT false,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS nee_addresses_select_own ON public.user_addresses;
CREATE POLICY nee_addresses_select_own ON public.user_addresses
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS nee_addresses_insert_own ON public.user_addresses;
CREATE POLICY nee_addresses_insert_own ON public.user_addresses
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS nee_addresses_update_own ON public.user_addresses;
CREATE POLICY nee_addresses_update_own ON public.user_addresses
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS nee_addresses_delete_own ON public.user_addresses;
CREATE POLICY nee_addresses_delete_own ON public.user_addresses
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_addresses TO authenticated;

ALTER TABLE public.service_requests
  ADD COLUMN IF NOT EXISTS service_address_id text,
  ADD COLUMN IF NOT EXISTS service_address_label text,
  ADD COLUMN IF NOT EXISTS service_formatted_address text,
  ADD COLUMN IF NOT EXISTS service_street text,
  ADD COLUMN IF NOT EXISTS service_number text,
  ADD COLUMN IF NOT EXISTS service_neighborhood text,
  ADD COLUMN IF NOT EXISTS service_city text,
  ADD COLUMN IF NOT EXISTS service_state text,
  ADD COLUMN IF NOT EXISTS service_country text,
  ADD COLUMN IF NOT EXISTS service_postal_code text,
  ADD COLUMN IF NOT EXISTS service_latitude double precision,
  ADD COLUMN IF NOT EXISTS service_longitude double precision,
  ADD COLUMN IF NOT EXISTS service_apartment text,
  ADD COLUMN IF NOT EXISTS service_floor text,
  ADD COLUMN IF NOT EXISTS service_reference text;
