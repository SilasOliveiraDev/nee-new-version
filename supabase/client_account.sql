-- Preferências, FAQ, legal, exclusão de conta e avatar do cliente.

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id text PRIMARY KEY,
  push_enabled boolean NOT NULL DEFAULT true,
  chat_messages boolean NOT NULL DEFAULT true,
  new_offers boolean NOT NULL DEFAULT true,
  request_updates boolean NOT NULL DEFAULT true,
  professional_on_the_way boolean NOT NULL DEFAULT true,
  service_started boolean NOT NULL DEFAULT true,
  service_finished boolean NOT NULL DEFAULT true,
  reminders boolean NOT NULL DEFAULT true,
  marketing boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.faq_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL,
  question text NOT NULL,
  answer text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  published boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.legal_documents (
  slug text PRIMARY KEY,
  title text NOT NULL,
  body text NOT NULL,
  version text NOT NULL DEFAULT '1.0',
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.app_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL DEFAULT '{}'::jsonb
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faq_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS nee_notif_select ON public.notification_preferences;
CREATE POLICY nee_notif_select ON public.notification_preferences
  FOR SELECT TO authenticated USING (user_id = auth.uid()::text);
DROP POLICY IF EXISTS nee_notif_upsert ON public.notification_preferences;
CREATE POLICY nee_notif_upsert ON public.notification_preferences
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid()::text);
DROP POLICY IF EXISTS nee_notif_update ON public.notification_preferences;
CREATE POLICY nee_notif_update ON public.notification_preferences
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_faq_select ON public.faq_items;
CREATE POLICY nee_faq_select ON public.faq_items
  FOR SELECT TO anon, authenticated USING (published = true);

DROP POLICY IF EXISTS nee_legal_select ON public.legal_documents;
CREATE POLICY nee_legal_select ON public.legal_documents
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS nee_settings_select ON public.app_settings;
CREATE POLICY nee_settings_select ON public.app_settings
  FOR SELECT TO anon, authenticated USING (true);

GRANT SELECT, INSERT, UPDATE ON public.notification_preferences TO authenticated;
GRANT SELECT ON public.faq_items TO anon, authenticated;
GRANT SELECT ON public.legal_documents TO anon, authenticated;
GRANT SELECT ON public.app_settings TO anon, authenticated;

INSERT INTO public.app_settings (key, value) VALUES
  ('password_reset_enabled', 'true'::jsonb),
  ('sms_verification_enabled', 'true'::jsonb),
  ('email_verification_enabled', 'true'::jsonb),
  ('faq_enabled', 'true'::jsonb),
  ('support_enabled', 'true'::jsonb),
  ('account_deletion_enabled', 'true'::jsonb),
  ('maintenance_mode', 'false'::jsonb)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.legal_documents (slug, title, body, version) VALUES
(
  'terms',
  'Términos y condiciones',
  'Ñee conecta a personas que necesitan un servicio con profesionales verificados en Bolivia. Al usar la aplicación aceptas coordinar el servicio dentro de Ñee, respetar a la otra parte y no compartir datos de contacto fuera de la plataforma antes de una contratación oficial. Ñee no es empleador de los profesionales. El contenido de este documento puede actualizarse; la versión vigente se muestra en la aplicación.',
  '1.0'
),
(
  'privacy',
  'Política de privacidad',
  'Tratamos tus datos para crear tu cuenta, mostrar profesionales cerca, gestionar solicitudes y mejorar Ñee. Conservamos el snapshot de dirección de cada solicitud aunque edites o elimines un lugar guardado. No vendemos tu información. Puedes solicitar la eliminación de tu cuenta desde Perfil.',
  '1.0'
)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.faq_items (category, question, answer, sort_order)
SELECT v.category, v.question, v.answer, v.sort_order
FROM (VALUES
  ('Primeros pasos', '¿Cómo pido un servicio?', 'Describe lo que necesitas, elige el lugar y publica la solicitud. Los profesionales compatibles pueden enviarte propuestas.', 1),
  ('Solicitudes', '¿Cómo cancelo una solicitud?', 'Abre la solicitud y elige Cancelar. Te pediremos un motivo. La solicitud queda en tu historial, no se elimina.', 1),
  ('Solicitudes', '¿Hablar con un profesional significa contratarlo?', 'No. Puedes preguntar sobre una propuesta. La relación oficial empieza cuando confirmas al profesional.', 2),
  ('Profesionales', '¿Cómo elijo a un profesional?', 'Revisa perfil, calificación y propuesta. Luego confirma. Los demás quedan notificados de forma respetuosa.', 1),
  ('Pagos', '¿Puedo pagar dentro de Ñee?', 'Por ahora coordinas el pago con el profesional. El pago dentro de Ñee llegará más adelante.', 1),
  ('Cancelaciones', '¿Qué pasa si cancelo varias veces?', 'Para proteger a los profesionales, varios cancelamentos seguidos pueden pausar nuevas solicitudes por unos minutos.', 1),
  ('Seguridad', '¿Debo compartir mi WhatsApp?', 'No. Coordina el servicio en el chat de Ñee. Así protegemos tu número y el del profesional.', 1),
  ('Cuenta', '¿Cómo cambio mi contraseña?', 'Ve a Perfil → Seguridad → Cambiar contraseña. Si la olvidaste, usa ¿Olvidaste tu contraseña? en el inicio de sesión.', 1),
  ('Notificaciones', '¿Por qué no recibo avisos?', 'Revisa Perfil → Notificaciones y también el permiso del sistema de tu teléfono. Ñee no puede activar un permiso bloqueado por iOS o Android.', 1)
) AS v(category, question, answer, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM public.faq_items LIMIT 1);

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS nee_avatar_select ON storage.objects;
CREATE POLICY nee_avatar_select ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'avatars' AND split_part(name, '/', 1) = auth.uid()::text);

DROP POLICY IF EXISTS nee_avatar_insert ON storage.objects;
CREATE POLICY nee_avatar_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND split_part(name, '/', 1) = auth.uid()::text);

DROP POLICY IF EXISTS nee_avatar_update ON storage.objects;
CREATE POLICY nee_avatar_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND split_part(name, '/', 1) = auth.uid()::text)
  WITH CHECK (bucket_id = 'avatars' AND split_part(name, '/', 1) = auth.uid()::text);

DROP POLICY IF EXISTS nee_avatar_delete ON storage.objects;
CREATE POLICY nee_avatar_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'avatars' AND split_part(name, '/', 1) = auth.uid()::text);

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  UPDATE public.users
  SET "isDeletado" = true,
      email = NULL,
      phone = NULL,
      name = 'Cuenta eliminada',
      "imagemPerfil" = NULL
  WHERE "UUID"::text = uid;
  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
