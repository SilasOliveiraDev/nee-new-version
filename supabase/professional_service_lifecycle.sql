-- Ciclo del servicio confirmado: en camino → en curso → finalizado.
-- El profesional no puede aceptar otro trabajo mientras tenga uno abierto.

CREATE OR REPLACE FUNCTION public.professional_open_service_id(
  p_professional_id text DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := COALESCE(NULLIF(btrim(p_professional_id), ''), auth.uid()::text);
  open_id bigint;
BEGIN
  IF uid IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT r.id INTO open_id
  FROM public.service_requests r
  WHERE COALESCE(r.selected_professional_id, r.profissional_id, r.target_professional_id) = uid
    AND COALESCE(r.status, '') !~* '(cancel|complet|final|expir|no se pudo)'
    AND (
      r.direct_status IN ('CONFIRMED')
      OR r.status ILIKE '%seleccion%'
      OR r.status ILIKE '%camino%'
      OR r.status ILIKE '%curso%'
      OR r.status ILIKE '%progreso%'
    )
  ORDER BY r.created_at DESC
  LIMIT 1;

  RETURN open_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.professional_advance_service(
  p_request_id bigint,
  p_action text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
  req public.service_requests%ROWTYPE;
  action text := upper(btrim(COALESCE(p_action, '')));
  assigned text;
  next_status text;
  event_name text;
  event_copy text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT * INTO req FROM public.service_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND');
  END IF;

  assigned := COALESCE(req.selected_professional_id, req.profissional_id, req.target_professional_id);
  IF assigned IS DISTINCT FROM uid THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF COALESCE(req.status, '') ~* '(cancel|complet|final|expir|no se pudo)' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'CLOSED');
  END IF;

  IF action = 'ON_THE_WAY' THEN
    IF req.status ILIKE '%camino%' OR req.status ILIKE '%curso%' THEN
      RETURN jsonb_build_object('ok', true, 'status', req.status);
    END IF;
    IF req.direct_status IS DISTINCT FROM 'CONFIRMED'
       AND req.status NOT ILIKE '%seleccion%' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'INVALID_STATE');
    END IF;
    next_status := 'Profesional en camino';
    event_name := 'PROFESSIONAL_ON_THE_WAY';
    event_copy := 'El profesional está en camino.';
  ELSIF action = 'START' THEN
    IF req.status ILIKE '%curso%' THEN
      RETURN jsonb_build_object('ok', true, 'status', req.status);
    END IF;
    IF req.status NOT ILIKE '%camino%' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'INVALID_STATE');
    END IF;
    next_status := 'Servicio en curso';
    event_name := 'SERVICE_STARTED';
    event_copy := 'El servicio ya está en curso.';
  ELSIF action = 'FINISH' THEN
    IF req.status NOT ILIKE '%curso%' AND req.status NOT ILIKE '%camino%' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'INVALID_STATE');
    END IF;
    next_status := 'Finalizado';
    event_name := 'SERVICE_FINISHED';
    event_copy := 'El profesional marcó el servicio como finalizado.';
  ELSE
    RETURN jsonb_build_object('ok', false, 'error', 'INVALID_ACTION');
  END IF;

  UPDATE public.service_requests
  SET status = next_status,
      disponivel = CASE WHEN action = 'FINISH' THEN false ELSE disponivel END
  WHERE id = p_request_id;

  IF action = 'FINISH' THEN
    INSERT INTO public.professional_operational_status (
      professional_id, status, current_service_id, status_since, updated_at
    ) VALUES (uid, 'AVAILABLE', NULL, now(), now())
    ON CONFLICT (professional_id) DO UPDATE
      SET status = 'AVAILABLE',
          current_service_id = NULL,
          status_since = now(),
          updated_at = now();
    PERFORM public.recalculate_professional_availability(uid);
  END IF;

  IF action = 'ON_THE_WAY' THEN
    INSERT INTO public.professional_operational_status (
      professional_id, status, current_service_id, status_since, updated_at
    ) VALUES (uid, 'BUSY', p_request_id::text, now(), now())
    ON CONFLICT (professional_id) DO UPDATE
      SET status = 'BUSY',
          current_service_id = EXCLUDED.current_service_id,
          status_since = now(),
          updated_at = now();
  END IF;

  BEGIN
    PERFORM public.append_service_system_event(
      p_request_id::text,
      event_name,
      event_copy,
      CASE WHEN action = 'FINISH' THEN 'COMPLETED' ELSE 'ACTIVE_SERVICE' END,
      CASE WHEN action = 'FINISH' THEN 'SERVICE_COMPLETED' ELSE 'ACTIVE' END,
      uid
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'No se pudo registrar el evento del servicio.';
  END;

  RETURN jsonb_build_object('ok', true, 'status', next_status);
END;
$$;

REVOKE ALL ON FUNCTION public.professional_open_service_id(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.professional_open_service_id(text) TO authenticated;
REVOKE ALL ON FUNCTION public.professional_advance_service(bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.professional_advance_service(bigint, text) TO authenticated;

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
  open_id bigint;
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
    SELECT c.id INTO conv_id
    FROM public.service_conversations c
    WHERE c.request_id = p_request_id::text
      AND c.professional_id = uid
    LIMIT 1;
    IF conv_id IS NOT NULL THEN
      INSERT INTO public.service_chat_messages (
        conversation_id, sender_type, message_type, content, delivery_status, metadata
      ) VALUES (
        conv_id, 'SYSTEM', 'SYSTEM',
        'El profesional no puede atender esta solicitud.',
        'SENT',
        jsonb_build_object('system_event', jsonb_build_object('type', 'DIRECT_DECLINED', 'occurred_at', now()))
      );
      UPDATE public.service_conversations
      SET mode = 'CANCELLED', status = 'CLOSED', updated_at = now()
      WHERE id = conv_id;
    END IF;
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

  open_id := public.professional_open_service_id(uid);
  IF open_id IS NOT NULL AND open_id IS DISTINCT FROM p_request_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'OPEN_SERVICE', 'open_request_id', open_id);
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
