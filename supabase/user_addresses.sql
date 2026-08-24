-- Lugares salvos do cliente (separados do endereço da conta).
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
