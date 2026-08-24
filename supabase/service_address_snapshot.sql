-- Snapshot imutável do endereço do serviço na solicitud.
-- O endereço da conta e os lugares salvos podem mudar depois;
-- estes campos permanecem com o pedido.

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
