-- Abre el chat al enviar una solicitud directa (antes el hilo solo nacía al aceptar).

CREATE OR REPLACE FUNCTION public.notify_direct_request(p_request_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  req public.service_requests%ROWTYPE;
  conv_id uuid;
  preview text := 'Solicitud enviada. Esperando respuesta.';
BEGIN
  SELECT * INTO req FROM public.service_requests WHERE id = p_request_id;
  IF NOT FOUND OR req.target_professional_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.service_conversations (
    request_id, customer_id, professional_id, mode, status,
    last_message_at, last_message_preview, updated_at
  ) VALUES (
    p_request_id::text,
    req.client_id,
    req.target_professional_id,
    'PRE_HIRE',
    'ACTIVE',
    now(),
    preview,
    now()
  )
  ON CONFLICT (request_id, professional_id) DO UPDATE
    SET updated_at = now(),
        last_message_at = COALESCE(public.service_conversations.last_message_at, now()),
        last_message_preview = COALESCE(
          NULLIF(public.service_conversations.last_message_preview, ''),
          preview
        )
  RETURNING id INTO conv_id;

  IF NOT EXISTS (
    SELECT 1 FROM public.service_chat_messages
    WHERE conversation_id = conv_id
      AND metadata -> 'system_event' ->> 'type' = 'DIRECT_REQUEST_SENT'
  ) THEN
    INSERT INTO public.service_chat_messages (
      conversation_id, sender_type, message_type, content, delivery_status, metadata
    ) VALUES (
      conv_id, 'SYSTEM', 'SYSTEM',
      'Enviaste una solicitud. Puedes agregar detalles aquí; te avisaremos cuando el profesional responda.',
      'SENT',
      jsonb_build_object(
        'system_event',
        jsonb_build_object('type', 'DIRECT_REQUEST_SENT', 'occurred_at', now())
      )
    );
  END IF;

  UPDATE public.service_conversations
  SET last_message_at = now(),
      last_message_preview = preview,
      updated_at = now()
  WHERE id = conv_id;

  PERFORM public.notify_service_inbox(
    req.target_professional_id,
    'DIRECT_REQUEST',
    'Nueva solicitud directa',
    COALESCE(req.title, 'Un cliente quiere solicitar tus servicios.'),
    'Ver solicitud',
    jsonb_build_object('request_id', p_request_id, 'conversation_id', conv_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.notify_direct_request(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.notify_direct_request(bigint) TO authenticated;

INSERT INTO public.service_conversations (
  request_id, customer_id, professional_id, mode, status,
  last_message_at, last_message_preview, updated_at
)
SELECT
  r.id::text,
  r.client_id,
  r.target_professional_id,
  'PRE_HIRE',
  'ACTIVE',
  now(),
  'Solicitud enviada. Esperando respuesta.',
  now()
FROM public.service_requests r
WHERE upper(COALESCE(r.request_kind, '')) = 'DIRECT'
  AND r.direct_status = 'PENDING_PROFESSIONAL_RESPONSE'
  AND r.target_professional_id IS NOT NULL
  AND r.client_id IS NOT NULL
ON CONFLICT (request_id, professional_id) DO NOTHING;

INSERT INTO public.service_chat_messages (
  conversation_id, sender_type, message_type, content, delivery_status, metadata
)
SELECT
  c.id,
  'SYSTEM',
  'SYSTEM',
  'Enviaste una solicitud. Puedes agregar detalles aquí; te avisaremos cuando el profesional responda.',
  'SENT',
  jsonb_build_object(
    'system_event',
    jsonb_build_object('type', 'DIRECT_REQUEST_SENT', 'occurred_at', now())
  )
FROM public.service_conversations c
JOIN public.service_requests r ON r.id::text = c.request_id
WHERE upper(COALESCE(r.request_kind, '')) = 'DIRECT'
  AND r.direct_status = 'PENDING_PROFESSIONAL_RESPONSE'
  AND NOT EXISTS (
    SELECT 1 FROM public.service_chat_messages m
    WHERE m.conversation_id = c.id
      AND m.metadata -> 'system_event' ->> 'type' = 'DIRECT_REQUEST_SENT'
  );
