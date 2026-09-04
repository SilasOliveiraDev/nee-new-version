-- Marca como lidas las notificaciones del usuario autenticado.
-- El cliente también persiste por UPDATE directo; esta RPC evita fallos silenciosos de RLS.

CREATE OR REPLACE FUNCTION public.mark_my_client_notices_read()
RETURNS void
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

  UPDATE public.notifications
  SET is_read = true,
      read_at = COALESCE(read_at, now())
  WHERE user_id = uid
    AND COALESCE(is_read, false) = false;

  UPDATE public.service_inbox
  SET read_at = now()
  WHERE user_id = uid
    AND read_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_my_client_notices_read() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_my_client_notices_read() TO authenticated;
