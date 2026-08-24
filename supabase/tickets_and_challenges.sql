-- Tickets de soporte y desafíos del día (cliente).

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id text NOT NULL,
  subject text NOT NULL,
  category text NOT NULL DEFAULT 'GENERAL',
  body text NOT NULL,
  status text NOT NULL DEFAULT 'OPEN',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS support_tickets_customer_idx
  ON public.support_tickets (customer_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.daily_challenges (
  slug text PRIMARY KEY,
  title text NOT NULL,
  description text NOT NULL,
  hint text,
  sort_order int NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.daily_challenge_completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  challenge_slug text NOT NULL REFERENCES public.daily_challenges(slug),
  day date NOT NULL DEFAULT ((timezone('America/La_Paz', now()))::date),
  completed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, challenge_slug, day)
);

CREATE INDEX IF NOT EXISTS daily_challenge_done_user_day_idx
  ON public.daily_challenge_completions (user_id, day);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_challenge_completions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS nee_tickets_select ON public.support_tickets;
CREATE POLICY nee_tickets_select ON public.support_tickets
  FOR SELECT TO authenticated
  USING (customer_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_tickets_insert ON public.support_tickets;
CREATE POLICY nee_tickets_insert ON public.support_tickets
  FOR INSERT TO authenticated
  WITH CHECK (customer_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_challenges_select ON public.daily_challenges;
CREATE POLICY nee_challenges_select ON public.daily_challenges
  FOR SELECT TO anon, authenticated
  USING (active = true);

DROP POLICY IF EXISTS nee_challenge_done_select ON public.daily_challenge_completions;
CREATE POLICY nee_challenge_done_select ON public.daily_challenge_completions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_challenge_done_insert ON public.daily_challenge_completions;
CREATE POLICY nee_challenge_done_insert ON public.daily_challenge_completions
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid()::text);

GRANT SELECT, INSERT ON public.support_tickets TO authenticated;
GRANT SELECT ON public.daily_challenges TO anon, authenticated;
GRANT SELECT, INSERT ON public.daily_challenge_completions TO authenticated;

INSERT INTO public.daily_challenges (slug, title, description, hint, sort_order) VALUES
  ('foto_perfil', 'Pon tu cara en Ñee', 'Sube o confirma tu foto de perfil para que el profesional te reconozca.', 'Perfil → Editar perfil', 10),
  ('direccion_casa', 'Deja lista tu dirección', 'Guarda casa, trabajo u otro lugar. Así no lo escribes en cada solicitud.', 'Perfil → Mis direcciones', 20),
  ('primera_solicitud', 'Cuenta qué necesitas', 'Publica una solicitud o pide un servicio directo. Pedir no es contratar.', 'Inicio → Buscar servicio', 30),
  ('ver_profesional', 'Mira a alguien cerca', 'Abre el perfil de un profesional destacado y revisa su disponibilidad.', 'Inicio → Destacados', 40),
  ('escribir_soporte', 'Prueba el soporte', 'Si algo no cuadra, abre un ticket. El equipo de Ñee te responde ahí.', 'Perfil → Mis tickets', 50)
ON CONFLICT (slug) DO UPDATE
  SET title = EXCLUDED.title,
      description = EXCLUDED.description,
      hint = EXCLUDED.hint,
      sort_order = EXCLUDED.sort_order,
      active = true;
