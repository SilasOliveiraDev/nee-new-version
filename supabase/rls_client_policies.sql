-- Policies e defaults para o app cliente Ñee gravar em
-- public.users e public.service_requests.
-- Rodar no SQL Editor do projeto zhubjmdpvkvbkbfcxeyh.
-- Nao recria tabelas: o schema oficial ja existe.

CREATE SEQUENCE IF NOT EXISTS public.users_id_seq;
SELECT setval(
  'public.users_id_seq',
  GREATEST(COALESCE((SELECT MAX(id) FROM public.users), 1), 1),
  true
);
ALTER TABLE public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq');
ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;

CREATE SEQUENCE IF NOT EXISTS public.service_requests_id_seq;
SELECT setval(
  'public.service_requests_id_seq',
  GREATEST(COALESCE((SELECT MAX(id) FROM public.service_requests), 1), 1),
  true
);
ALTER TABLE public.service_requests
  ALTER COLUMN id SET DEFAULT nextval('public.service_requests_id_seq');
ALTER SEQUENCE public.service_requests_id_seq OWNED BY public.service_requests.id;

CREATE UNIQUE INDEX IF NOT EXISTS users_uuid_unique ON public.users ("UUID");

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS nee_users_select_own ON public.users;
CREATE POLICY nee_users_select_own ON public.users
  FOR SELECT TO authenticated
  USING ("UUID" = auth.uid());

DROP POLICY IF EXISTS nee_users_insert_own ON public.users;
CREATE POLICY nee_users_insert_own ON public.users
  FOR INSERT TO authenticated
  WITH CHECK ("UUID" = auth.uid());

DROP POLICY IF EXISTS nee_users_update_own ON public.users;
CREATE POLICY nee_users_update_own ON public.users
  FOR UPDATE TO authenticated
  USING ("UUID" = auth.uid())
  WITH CHECK ("UUID" = auth.uid());

DROP POLICY IF EXISTS nee_requests_select_own ON public.service_requests;
CREATE POLICY nee_requests_select_own ON public.service_requests
  FOR SELECT TO authenticated
  USING (client_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_requests_insert_own ON public.service_requests;
CREATE POLICY nee_requests_insert_own ON public.service_requests
  FOR INSERT TO authenticated
  WITH CHECK (client_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_requests_update_own ON public.service_requests;
CREATE POLICY nee_requests_update_own ON public.service_requests
  FOR UPDATE TO authenticated
  USING (client_id = auth.uid()::text)
  WITH CHECK (client_id = auth.uid()::text);
