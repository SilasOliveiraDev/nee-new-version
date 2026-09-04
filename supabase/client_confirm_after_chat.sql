-- El cliente puede confirmar el servicio después de conversar, sin esperar una propuesta formal.

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
  IF req.direct_status IS DISTINCT FROM 'NEGOTIATION'
     AND req.direct_status IS DISTINCT FROM 'PENDING_CONFIRMATION' THEN
    RAISE EXCEPTION 'invalid_state';
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
