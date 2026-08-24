-- Contratação direta, agenda, disponibilidade e encerramento de chat.

INSERT INTO public.app_settings (key, value) VALUES
  ('default_service_buffer_minutes', '15'::jsonb),
  ('direct_request_expiration_minutes', '120'::jsonb)
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.service_requests
  ADD COLUMN IF NOT EXISTS request_kind text DEFAULT 'MARKETPLACE',
  ADD COLUMN IF NOT EXISTS target_professional_id text,
  ADD COLUMN IF NOT EXISTS direct_status text,
  ADD COLUMN IF NOT EXISTS requested_start timestamptz,
  ADD COLUMN IF NOT EXISTS requested_end timestamptz,
  ADD COLUMN IF NOT EXISTS agreed_price double precision,
  ADD COLUMN IF NOT EXISTS agreed_duration_minutes int,
  ADD COLUMN IF NOT EXISTS decline_reason text;

ALTER TABLE public.service_conversations
  ADD COLUMN IF NOT EXISTS closed_reason text,
  ADD COLUMN IF NOT EXISTS closed_at timestamptz;

CREATE TABLE IF NOT EXISTS public.professional_operational_status (
  professional_id text PRIMARY KEY,
  status text NOT NULL DEFAULT 'AVAILABLE',
  current_service_id text,
  status_since timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.professional_availability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  professional_id text NOT NULL,
  day_of_week int NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  accepts_immediate_requests boolean NOT NULL DEFAULT true,
  enabled boolean NOT NULL DEFAULT true,
  timezone text NOT NULL DEFAULT 'America/La_Paz'
);

CREATE TABLE IF NOT EXISTS public.professional_schedule (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  professional_id text NOT NULL,
  service_request_id text,
  start_at timestamptz NOT NULL,
  estimated_end_at timestamptz NOT NULL,
  actual_end_at timestamptz,
  buffer_minutes int NOT NULL DEFAULT 15,
  status text NOT NULL DEFAULT 'RESERVED',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS pro_sched_pro_idx
  ON public.professional_schedule (professional_id, start_at);
CREATE INDEX IF NOT EXISTS pro_avail_pro_idx
  ON public.professional_availability (professional_id, day_of_week);

ALTER TABLE public.professional_operational_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.professional_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.professional_schedule ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS nee_ops_select ON public.professional_operational_status;
CREATE POLICY nee_ops_select ON public.professional_operational_status
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS nee_ops_upsert ON public.professional_operational_status;
CREATE POLICY nee_ops_upsert ON public.professional_operational_status
  FOR INSERT TO authenticated WITH CHECK (professional_id = auth.uid()::text);
DROP POLICY IF EXISTS nee_ops_update ON public.professional_operational_status;
CREATE POLICY nee_ops_update ON public.professional_operational_status
  FOR UPDATE TO authenticated
  USING (professional_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_avail_select ON public.professional_availability;
CREATE POLICY nee_avail_select ON public.professional_availability
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS nee_avail_write ON public.professional_availability;
CREATE POLICY nee_avail_write ON public.professional_availability
  FOR ALL TO authenticated
  USING (professional_id = auth.uid()::text)
  WITH CHECK (professional_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_sched_select ON public.professional_schedule;
CREATE POLICY nee_sched_select ON public.professional_schedule
  FOR SELECT TO authenticated
  USING (
    professional_id = auth.uid()::text
    OR EXISTS (
      SELECT 1 FROM public.service_requests r
      WHERE r.id::text = service_request_id AND r.client_id = auth.uid()::text
    )
  );

GRANT SELECT, INSERT, UPDATE ON public.professional_operational_status TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.professional_availability TO authenticated;
GRANT SELECT ON public.professional_schedule TO authenticated;

CREATE OR REPLACE FUNCTION public.service_buffer_minutes()
RETURNS int LANGUAGE sql STABLE AS $$
  SELECT COALESCE((SELECT (value #>> '{}')::int FROM public.app_settings WHERE key = 'default_service_buffer_minutes'), 15);
$$;

CREATE OR REPLACE FUNCTION public.professional_next_free_at(p_professional_id text)
RETURNS timestamptz
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  buf int := public.service_buffer_minutes();
  busy_until timestamptz;
  ops text;
BEGIN
  SELECT status INTO ops FROM public.professional_operational_status WHERE professional_id = p_professional_id;
  IF ops IN ('OFFLINE', 'PAUSED') THEN
    RETURN NULL;
  END IF;
  SELECT max(estimated_end_at + make_interval(mins => COALESCE(buffer_minutes, buf)))
    INTO busy_until
  FROM public.professional_schedule
  WHERE professional_id = p_professional_id
    AND status IN ('RESERVED', 'CONFIRMED', 'IN_PROGRESS')
    AND estimated_end_at + make_interval(mins => COALESCE(buffer_minutes, buf)) > now();
  RETURN COALESCE(busy_until, now());
END;
$$;

CREATE OR REPLACE FUNCTION public.professional_public_status(p_professional_id text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  ops text := 'AVAILABLE';
  next_at timestamptz;
  accepting boolean := true;
BEGIN
  SELECT status INTO ops FROM public.professional_operational_status WHERE professional_id = p_professional_id;
  ops := COALESCE(ops, 'AVAILABLE');
  next_at := public.professional_next_free_at(p_professional_id);
  IF ops IN ('OFFLINE', 'PAUSED') THEN
    accepting := false;
  END IF;
  IF next_at IS NULL THEN
    RETURN jsonb_build_object(
      'status', ops,
      'accepting_requests', accepting,
      'next_available_at', NULL,
      'label_code', CASE WHEN ops = 'PAUSED' THEN 'NOT_ACCEPTING' ELSE 'UNAVAILABLE' END
    );
  END IF;
  IF next_at > now() + interval '2 minutes' THEN
    RETURN jsonb_build_object(
      'status', 'BUSY',
      'accepting_requests', accepting,
      'next_available_at', next_at,
      'label_code', 'BUSY_UNTIL'
    );
  END IF;
  RETURN jsonb_build_object(
    'status', 'AVAILABLE',
    'accepting_requests', accepting,
    'next_available_at', next_at,
    'label_code', 'AVAILABLE_NOW'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.schedule_conflicts(
  p_professional_id text,
  p_start timestamptz,
  p_end timestamptz
) RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.professional_schedule s
    WHERE s.professional_id = p_professional_id
      AND s.status IN ('RESERVED', 'CONFIRMED', 'IN_PROGRESS')
      AND tstzrange(s.start_at, s.estimated_end_at + make_interval(mins => s.buffer_minutes), '[)') &&
          tstzrange(p_start, p_end + make_interval(mins => public.service_buffer_minutes()), '[)')
  );
$$;

CREATE OR REPLACE FUNCTION public.close_service_conversations(
  p_request_id text,
  p_reason text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.service_conversations
  SET status = 'CLOSED',
      closed_reason = p_reason,
      closed_at = now(),
      mode = CASE WHEN p_reason = 'SERVICE_CANCELLED' THEN 'CANCELLED' ELSE 'COMPLETED' END,
      updated_at = now()
  WHERE request_id = p_request_id
    AND status IS DISTINCT FROM 'CLOSED';
END;
$$;

REVOKE ALL ON FUNCTION public.close_service_conversations(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.close_service_conversations(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.respond_direct_request(
  p_request_id bigint,
  p_accept boolean,
  p_reason text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
  req public.service_requests%ROWTYPE;
  conv_id uuid;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT * INTO req FROM public.service_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR req.target_professional_id IS DISTINCT FROM uid THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF req.direct_status IS DISTINCT FROM 'PENDING_PROFESSIONAL_RESPONSE' THEN
    RAISE EXCEPTION 'invalid_state';
  END IF;

  IF NOT p_accept THEN
    UPDATE public.service_requests
    SET direct_status = 'DECLINED',
        decline_reason = p_reason,
        status = 'Cancelado por el profesional',
        disponivel = false
    WHERE id = p_request_id;
    PERFORM public.notify_service_inbox(
      req.client_id,
      'DIRECT_DECLINED',
      'El profesional no puede atender',
      'Puedes buscar otro profesional disponible.',
      'Buscar otro profesional',
      jsonb_build_object('request_id', p_request_id)
    );
    RETURN jsonb_build_object('ok', true, 'status', 'DECLINED');
  END IF;

  IF req.requested_start IS NOT NULL AND req.requested_end IS NOT NULL
     AND public.schedule_conflicts(uid, req.requested_start, req.requested_end) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'CONFLICT');
  END IF;

  UPDATE public.service_requests
  SET direct_status = 'NEGOTIATION',
      status = 'Conversando',
      profissional_id = uid
  WHERE id = p_request_id;

  INSERT INTO public.service_conversations (
    request_id, customer_id, professional_id, mode, status, updated_at
  ) VALUES (
    p_request_id::text, req.client_id, uid, 'NEGOTIATION', 'ACTIVE', now()
  )
  ON CONFLICT (request_id, professional_id) DO UPDATE
    SET mode = 'NEGOTIATION', status = 'ACTIVE', updated_at = now()
  RETURNING id INTO conv_id;

  INSERT INTO public.service_chat_messages (
    conversation_id, sender_type, message_type, content, delivery_status, metadata
  ) VALUES (
    conv_id, 'SYSTEM', 'SYSTEM',
    'El profesional aceptó conversar. Coordinen los detalles del servicio.',
    'SENT',
    jsonb_build_object('system_event', jsonb_build_object('type', 'DIRECT_REQUEST_ACCEPTED', 'occurred_at', now()))
  );

  PERFORM public.notify_service_inbox(
    req.client_id,
    'DIRECT_ACCEPTED',
    'Aceptó tu solicitud',
    'Ahora pueden coordinar los detalles del servicio.',
    'Abrir chat',
    jsonb_build_object('request_id', p_request_id, 'conversation_id', conv_id)
  );

  RETURN jsonb_build_object('ok', true, 'status', 'NEGOTIATION', 'conversation_id', conv_id);
END;
$$;

REVOKE ALL ON FUNCTION public.respond_direct_request(bigint, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_direct_request(bigint, boolean, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.confirm_direct_service(
  p_request_id bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
  req public.service_requests%ROWTYPE;
  start_at timestamptz;
  end_at timestamptz;
  buf int := public.service_buffer_minutes();
  conv_id uuid;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT * INTO req FROM public.service_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR req.client_id IS DISTINCT FROM uid THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  start_at := COALESCE(req.requested_start, now());
  end_at := COALESCE(req.requested_end, start_at + interval '1 hour');

  PERFORM pg_advisory_xact_lock(hashtext(COALESCE(req.target_professional_id, req.profissional_id)));

  IF public.schedule_conflicts(COALESCE(req.target_professional_id, req.profissional_id), start_at, end_at) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'CONFLICT',
      'next_available_at', public.professional_next_free_at(COALESCE(req.target_professional_id, req.profissional_id))
    );
  END IF;

  UPDATE public.service_requests
  SET direct_status = 'CONFIRMED',
      status = 'Profesional seleccionado',
      selected_professional_id = COALESCE(req.target_professional_id, req.profissional_id),
      profissional_id = COALESCE(req.target_professional_id, req.profissional_id)
  WHERE id = p_request_id;

  INSERT INTO public.professional_schedule (
    professional_id, service_request_id, start_at, estimated_end_at, buffer_minutes, status
  ) VALUES (
    COALESCE(req.target_professional_id, req.profissional_id),
    p_request_id::text,
    start_at,
    end_at,
    buf,
    'CONFIRMED'
  );

  INSERT INTO public.service_conversations (
    request_id, customer_id, professional_id, mode, status, updated_at
  ) VALUES (
    p_request_id::text, uid, COALESCE(req.target_professional_id, req.profissional_id),
    'ACTIVE_SERVICE', 'ACTIVE', now()
  )
  ON CONFLICT (request_id, professional_id) DO UPDATE
    SET mode = 'ACTIVE_SERVICE', status = 'ACTIVE', updated_at = now()
  RETURNING id INTO conv_id;

  INSERT INTO public.service_chat_messages (
    conversation_id, sender_type, message_type, content, delivery_status, metadata
  ) VALUES (
    conv_id, 'SYSTEM', 'SYSTEM',
    'Servicio confirmado. Ya pueden coordinar la llegada desde Ñee.',
    'SENT',
    jsonb_build_object('system_event', jsonb_build_object('type', 'SERVICE_CONFIRMED', 'occurred_at', now()))
  );

  IF start_at <= now() + interval '15 minutes' THEN
    INSERT INTO public.professional_operational_status (professional_id, status, current_service_id, status_since, updated_at)
    VALUES (COALESCE(req.target_professional_id, req.profissional_id), 'BUSY', p_request_id::text, now(), now())
    ON CONFLICT (professional_id) DO UPDATE
      SET status = 'BUSY',
          current_service_id = EXCLUDED.current_service_id,
          status_since = now(),
          updated_at = now();
  END IF;

  PERFORM public.notify_service_inbox(
    COALESCE(req.target_professional_id, req.profissional_id),
    'SERVICE_CONFIRMED',
    'Servicio confirmado',
    'El cliente confirmó el servicio.',
    'Ver servicio',
    jsonb_build_object('request_id', p_request_id)
  );

  RETURN jsonb_build_object('ok', true, 'conversation_id', conv_id);
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_direct_service(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_direct_service(bigint) TO authenticated;

CREATE TABLE IF NOT EXISTS public.schedule_slot_holds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  professional_id text NOT NULL,
  request_id text,
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.schedule_slot_holds ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.notify_direct_request(p_request_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  req public.service_requests%ROWTYPE;
BEGIN
  SELECT * INTO req FROM public.service_requests WHERE id = p_request_id;
  IF NOT FOUND OR req.target_professional_id IS NULL THEN
    RETURN;
  END IF;
  PERFORM public.notify_service_inbox(
    req.target_professional_id,
    'DIRECT_REQUEST',
    'Nueva solicitud directa',
    COALESCE(req.title, 'Un cliente quiere solicitar tus servicios.'),
    'Ver solicitud',
    jsonb_build_object('request_id', p_request_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.notify_direct_request(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.notify_direct_request(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.propose_direct_terms(
  p_request_id bigint,
  p_start timestamptz,
  p_end timestamptz,
  p_price double precision,
  p_duration_minutes int
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
  req public.service_requests%ROWTYPE;
  conv_id uuid;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT * INTO req FROM public.service_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR COALESCE(req.target_professional_id, req.profissional_id) IS DISTINCT FROM uid THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF public.schedule_conflicts(uid, p_start, p_end) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'CONFLICT',
      'next_available_at', public.professional_next_free_at(uid));
  END IF;
  UPDATE public.service_requests
  SET requested_start = p_start,
      requested_end = p_end,
      agreed_price = p_price,
      agreed_duration_minutes = p_duration_minutes,
      direct_status = 'PENDING_CONFIRMATION',
      status = 'Pendiente de confirmación'
  WHERE id = p_request_id;

  SELECT id INTO conv_id FROM public.service_conversations
  WHERE request_id = p_request_id::text AND professional_id = uid;

  IF conv_id IS NOT NULL THEN
    INSERT INTO public.service_chat_messages (
      conversation_id, sender_type, message_type, content, delivery_status, metadata
    ) VALUES (
      conv_id, 'SYSTEM', 'SYSTEM',
      'El profesional está listo para confirmar el servicio.',
      'SENT',
      jsonb_build_object('system_event', jsonb_build_object('type', 'FINAL_PROPOSAL_SENT', 'occurred_at', now()))
    );
  END IF;

  PERFORM public.notify_service_inbox(
    req.client_id,
    'FINAL_PROPOSAL',
    'Listo para confirmar',
    'Revisa la propuesta final y confirma el servicio.',
    'Confirmar servicio',
    jsonb_build_object('request_id', p_request_id)
  );
  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.propose_direct_terms(bigint, timestamptz, timestamptz, double precision, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.propose_direct_terms(bigint, timestamptz, timestamptz, double precision, int) TO authenticated;

CREATE OR REPLACE FUNCTION public.cancel_direct_request(p_request_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
  req public.service_requests%ROWTYPE;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT * INTO req FROM public.service_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR req.client_id IS DISTINCT FROM uid THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF req.direct_status IN ('CONFIRMED') THEN
    RAISE EXCEPTION 'use_official_cancel';
  END IF;
  UPDATE public.service_requests
  SET direct_status = 'CANCELLED',
      status = 'Cancelado por el cliente',
      disponivel = false
  WHERE id = p_request_id;
  PERFORM public.close_service_conversations(p_request_id::text, 'SERVICE_CANCELLED');
  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_direct_request(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_direct_request(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.recalculate_professional_availability(p_professional_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  busy_id text;
  ops text;
BEGIN
  SELECT current_service_id, status INTO busy_id, ops
  FROM public.professional_operational_status
  WHERE professional_id = p_professional_id;

  IF ops IN ('OFFLINE', 'PAUSED') THEN
    RETURN;
  END IF;

  SELECT service_request_id INTO busy_id
  FROM public.professional_schedule
  WHERE professional_id = p_professional_id
    AND status = 'IN_PROGRESS'
  ORDER BY start_at DESC
  LIMIT 1;

  IF busy_id IS NOT NULL THEN
    INSERT INTO public.professional_operational_status (professional_id, status, current_service_id, status_since, updated_at)
    VALUES (p_professional_id, 'BUSY', busy_id, now(), now())
    ON CONFLICT (professional_id) DO UPDATE
      SET status = 'BUSY', current_service_id = EXCLUDED.current_service_id, updated_at = now();
  ELSE
    INSERT INTO public.professional_operational_status (professional_id, status, current_service_id, status_since, updated_at)
    VALUES (p_professional_id, 'AVAILABLE', NULL, now(), now())
    ON CONFLICT (professional_id) DO UPDATE
      SET status = 'AVAILABLE', current_service_id = NULL, updated_at = now();
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.recalculate_professional_availability(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.recalculate_professional_availability(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.expire_stale_direct_requests()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  mins int := COALESCE((SELECT (value #>> '{}')::int FROM public.app_settings WHERE key = 'direct_request_expiration_minutes'), 120);
  n int := 0;
  rec record;
BEGIN
  FOR rec IN
    SELECT id, client_id FROM public.service_requests
    WHERE request_kind = 'DIRECT'
      AND direct_status = 'PENDING_PROFESSIONAL_RESPONSE'
      AND created_at < now() - make_interval(mins => mins)
  LOOP
    UPDATE public.service_requests
    SET direct_status = 'EXPIRED', status = 'Expirado', disponivel = false
    WHERE id = rec.id;
    PERFORM public.notify_service_inbox(
      rec.client_id,
      'DIRECT_EXPIRED',
      'No respondió a tiempo',
      'Puedes intentar más tarde o buscar otro profesional disponible.',
      'Buscar otro profesional',
      jsonb_build_object('request_id', rec.id)
    );
    n := n + 1;
  END LOOP;
  RETURN n;
END;
$$;

CREATE OR REPLACE FUNCTION public.professional_statuses(p_ids text[])
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(jsonb_object_agg(id, public.professional_public_status(id)), '{}'::jsonb)
  FROM unnest(p_ids) AS id;
$$;

GRANT EXECUTE ON FUNCTION public.professional_public_status(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.professional_next_free_at(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.professional_statuses(text[]) TO authenticated, anon;

CREATE OR REPLACE FUNCTION public.sync_request_chat_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status ILIKE '%complet%' OR NEW.status ILIKE '%final%' THEN
    PERFORM public.close_service_conversations(NEW.id::text, 'SERVICE_COMPLETED');
    UPDATE public.professional_schedule
    SET status = 'COMPLETED', actual_end_at = COALESCE(actual_end_at, now())
    WHERE service_request_id = NEW.id::text
      AND status IN ('RESERVED', 'CONFIRMED', 'IN_PROGRESS');
    IF COALESCE(NEW.profissional_id, NEW.selected_professional_id, NEW.target_professional_id) IS NOT NULL THEN
      PERFORM public.recalculate_professional_availability(
        COALESCE(NEW.profissional_id, NEW.selected_professional_id, NEW.target_professional_id)
      );
    END IF;
  ELSIF NEW.status ILIKE '%cancel%' THEN
    PERFORM public.close_service_conversations(NEW.id::text, 'SERVICE_CANCELLED');
    UPDATE public.professional_schedule
    SET status = 'CANCELLED'
    WHERE service_request_id = NEW.id::text
      AND status IN ('RESERVED', 'CONFIRMED', 'IN_PROGRESS');
    IF COALESCE(NEW.profissional_id, NEW.selected_professional_id, NEW.target_professional_id) IS NOT NULL THEN
      PERFORM public.recalculate_professional_availability(
        COALESCE(NEW.profissional_id, NEW.selected_professional_id, NEW.target_professional_id)
      );
    END IF;
  ELSIF NEW.status ILIKE '%curso%' OR NEW.status ILIKE '%progreso%' THEN
    UPDATE public.professional_schedule
    SET status = 'IN_PROGRESS'
    WHERE service_request_id = NEW.id::text
      AND status IN ('RESERVED', 'CONFIRMED');
    IF COALESCE(NEW.profissional_id, NEW.selected_professional_id) IS NOT NULL THEN
      INSERT INTO public.professional_operational_status (professional_id, status, current_service_id, status_since, updated_at)
      VALUES (COALESCE(NEW.profissional_id, NEW.selected_professional_id), 'BUSY', NEW.id::text, now(), now())
      ON CONFLICT (professional_id) DO UPDATE
        SET status = 'BUSY', current_service_id = EXCLUDED.current_service_id, status_since = now(), updated_at = now();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_request_chat_lifecycle ON public.service_requests;
CREATE TRIGGER trg_request_chat_lifecycle
AFTER UPDATE OF status ON public.service_requests
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION public.sync_request_chat_lifecycle();
