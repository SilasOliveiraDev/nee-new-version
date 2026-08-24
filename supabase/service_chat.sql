-- Chat do serviço: PRE_HIRE vs conexão oficial. Não reutiliza public.messages/chats.

ALTER TABLE public.service_requests
  ADD COLUMN IF NOT EXISTS selected_professional_id text;

CREATE TABLE IF NOT EXISTS public.service_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id text NOT NULL,
  offer_id text,
  customer_id text NOT NULL,
  professional_id text NOT NULL,
  mode text NOT NULL DEFAULT 'PRE_HIRE',
  status text NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_message_at timestamptz,
  last_message_preview text,
  UNIQUE (request_id, professional_id)
);

CREATE TABLE IF NOT EXISTS public.service_chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.service_conversations(id) ON DELETE CASCADE,
  sender_id text,
  sender_type text NOT NULL,
  message_type text NOT NULL DEFAULT 'TEXT',
  content text,
  media_url text,
  metadata jsonb,
  client_key text,
  delivery_status text NOT NULL DEFAULT 'SENT',
  sent_at timestamptz NOT NULL DEFAULT now(),
  delivered_at timestamptz,
  read_at timestamptz,
  deleted_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.service_inbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  kind text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  cta text,
  payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS service_chat_messages_client_key
  ON public.service_chat_messages (conversation_id, client_key)
  WHERE client_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS service_conversations_customer_idx
  ON public.service_conversations (customer_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS service_conversations_pro_idx
  ON public.service_conversations (professional_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS service_chat_messages_conv_idx
  ON public.service_chat_messages (conversation_id, sent_at);
CREATE INDEX IF NOT EXISTS service_inbox_user_idx
  ON public.service_inbox (user_id, created_at DESC);

ALTER TABLE public.service_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_inbox ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS nee_conv_select ON public.service_conversations;
CREATE POLICY nee_conv_select ON public.service_conversations
  FOR SELECT TO authenticated
  USING (customer_id = auth.uid()::text OR professional_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_conv_insert ON public.service_conversations;
CREATE POLICY nee_conv_insert ON public.service_conversations
  FOR INSERT TO authenticated
  WITH CHECK (customer_id = auth.uid()::text OR professional_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_conv_update ON public.service_conversations;
CREATE POLICY nee_conv_update ON public.service_conversations
  FOR UPDATE TO authenticated
  USING (customer_id = auth.uid()::text OR professional_id = auth.uid()::text)
  WITH CHECK (customer_id = auth.uid()::text OR professional_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_msg_select ON public.service_chat_messages;
CREATE POLICY nee_msg_select ON public.service_chat_messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.service_conversations c
      WHERE c.id = conversation_id
        AND (c.customer_id = auth.uid()::text OR c.professional_id = auth.uid()::text)
    )
  );

DROP POLICY IF EXISTS nee_msg_insert ON public.service_chat_messages;
CREATE POLICY nee_msg_insert ON public.service_chat_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()::text
    AND sender_type IN ('CUSTOMER', 'PROFESSIONAL')
    AND EXISTS (
      SELECT 1 FROM public.service_conversations c
      WHERE c.id = conversation_id
        AND c.status = 'ACTIVE'
        AND (c.customer_id = auth.uid()::text OR c.professional_id = auth.uid()::text)
    )
  );

DROP POLICY IF EXISTS nee_msg_update ON public.service_chat_messages;
CREATE POLICY nee_msg_update ON public.service_chat_messages
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.service_conversations c
      WHERE c.id = conversation_id
        AND (c.customer_id = auth.uid()::text OR c.professional_id = auth.uid()::text)
    )
  );

DROP POLICY IF EXISTS nee_inbox_select ON public.service_inbox;
CREATE POLICY nee_inbox_select ON public.service_inbox
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_inbox_update ON public.service_inbox;
CREATE POLICY nee_inbox_update ON public.service_inbox
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()::text);

GRANT SELECT, INSERT, UPDATE ON public.service_conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.service_chat_messages TO authenticated;
GRANT SELECT, UPDATE ON public.service_inbox TO authenticated;

ALTER TABLE public.service_conversations REPLICA IDENTITY FULL;
ALTER TABLE public.service_chat_messages REPLICA IDENTITY FULL;
ALTER TABLE public.service_inbox REPLICA IDENTITY FULL;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.service_conversations;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.service_chat_messages;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.service_inbox;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

INSERT INTO storage.buckets (id, name, public)
VALUES ('service-chat', 'service-chat', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS nee_chat_storage_select ON storage.objects;
CREATE POLICY nee_chat_storage_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'service-chat'
    AND EXISTS (
      SELECT 1 FROM public.service_conversations c
      WHERE c.id::text = split_part(name, '/', 1)
        AND (c.customer_id = auth.uid()::text OR c.professional_id = auth.uid()::text)
    )
  );

DROP POLICY IF EXISTS nee_chat_storage_insert ON storage.objects;
CREATE POLICY nee_chat_storage_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'service-chat'
    AND split_part(name, '/', 2) = auth.uid()::text
    AND EXISTS (
      SELECT 1 FROM public.service_conversations c
      WHERE c.id::text = split_part(name, '/', 1)
        AND c.status = 'ACTIVE'
        AND (c.customer_id = auth.uid()::text OR c.professional_id = auth.uid()::text)
    )
  );

DROP POLICY IF EXISTS nee_chat_storage_update ON storage.objects;
CREATE POLICY nee_chat_storage_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'service-chat'
    AND split_part(name, '/', 2) = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'service-chat'
    AND split_part(name, '/', 2) = auth.uid()::text
  );

CREATE OR REPLACE FUNCTION public.notify_service_inbox(
  p_user_id text,
  p_kind text,
  p_title text,
  p_body text,
  p_cta text DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.service_inbox (user_id, kind, title, body, cta, payload)
  VALUES (p_user_id, p_kind, p_title, p_body, p_cta, p_payload);
END;
$$;

CREATE OR REPLACE FUNCTION public.select_professional_for_request(
  p_request_id bigint,
  p_offer_id bigint,
  p_professional_id text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
  req public.service_requests%ROWTYPE;
  conv_id uuid;
  other record;
  client_first text := 'El cliente';
  pro_first text := '';
  service_label text := 'el servicio';
  customer_copy text;
  professional_copy text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT * INTO req FROM public.service_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR req.client_id IS DISTINCT FROM uid THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF req.selected_professional_id IS NOT NULL
     AND req.selected_professional_id IS DISTINCT FROM p_professional_id THEN
    RAISE EXCEPTION 'already_selected';
  END IF;

  SELECT NULLIF(split_part(trim(name), ' ', 1), '')
    INTO client_first
  FROM public.users
  WHERE "UUID"::text = uid
  LIMIT 1;
  client_first := COALESCE(client_first, 'El cliente');

  SELECT NULLIF(split_part(trim(name), ' ', 1), '')
    INTO pro_first
  FROM public.users
  WHERE "UUID"::text = p_professional_id
  LIMIT 1;

  service_label := COALESCE(NULLIF(req.categoria, ''), NULLIF(req.title, ''), 'el servicio');
  customer_copy := 'Has elegido a este profesional para realizar el servicio.';
  IF pro_first IS NULL OR pro_first = '' THEN
    professional_copy := client_first || ' aceptó tu propuesta para ' || service_label
      || '. Ya pueden coordinar todos los detalles en este chat.';
  ELSE
    professional_copy := 'Hola ' || pro_first || ', ' || client_first
      || ' aceptó tu propuesta para ' || service_label
      || '. Ya pueden coordinar todos los detalles en este chat.';
  END IF;

  UPDATE public.service_requests
  SET selected_professional_id = p_professional_id,
      profissional_id = p_professional_id,
      status = 'Profesional seleccionado'
  WHERE id = p_request_id;

  UPDATE public.proposals
  SET status = 'ACCEPTED'
  WHERE id = p_offer_id AND service_request_id = p_request_id::text;

  UPDATE public.proposals
  SET status = 'NOT_SELECTED'
  WHERE service_request_id = p_request_id::text AND id <> p_offer_id;

  INSERT INTO public.service_conversations (
    request_id, offer_id, customer_id, professional_id, mode, status, updated_at
  ) VALUES (
    p_request_id::text, p_offer_id::text, uid, p_professional_id, 'ACTIVE_SERVICE', 'ACTIVE', now()
  )
  ON CONFLICT (request_id, professional_id) DO UPDATE
    SET mode = 'ACTIVE_SERVICE',
        status = 'ACTIVE',
        offer_id = COALESCE(EXCLUDED.offer_id, public.service_conversations.offer_id),
        updated_at = now()
  RETURNING id INTO conv_id;

  UPDATE public.service_conversations
  SET status = 'CLOSED_NOT_SELECTED', updated_at = now()
  WHERE request_id = p_request_id::text
    AND professional_id IS DISTINCT FROM p_professional_id
    AND status = 'ACTIVE';

  INSERT INTO public.service_chat_messages (
    conversation_id, sender_id, sender_type, message_type, content, delivery_status, metadata
  ) VALUES (
    conv_id,
    NULL,
    'SYSTEM',
    'SYSTEM',
    customer_copy,
    'SENT',
    jsonb_build_object(
      'system_event', jsonb_build_object(
        'type', 'PROFESSIONAL_SELECTED',
        'audience', 'CUSTOMER',
        'professional_id', p_professional_id,
        'occurred_at', now()
      )
    )
  );

  INSERT INTO public.service_chat_messages (
    conversation_id, sender_id, sender_type, message_type, content, delivery_status, metadata
  ) VALUES (
    conv_id,
    NULL,
    'SYSTEM',
    'SYSTEM',
    professional_copy,
    'SENT',
    jsonb_build_object(
      'system_event', jsonb_build_object(
        'type', 'PROPOSAL_ACCEPTED',
        'audience', 'PROFESSIONAL',
        'customer_name', client_first,
        'professional_name', pro_first,
        'service', service_label,
        'occurred_at', now()
      )
    )
  );

  UPDATE public.service_conversations
  SET last_message_at = now(),
      last_message_preview = 'Ñee: propuesta aceptada',
      updated_at = now()
  WHERE id = conv_id;

  PERFORM public.notify_service_inbox(
    p_professional_id,
    'PROFESSIONAL_SELECTED',
    '¡Tu propuesta fue aceptada! 🎉',
    professional_copy,
    'Ver servicio',
    jsonb_build_object('request_id', p_request_id, 'conversation_id', conv_id)
  );

  FOR other IN
    SELECT DISTINCT professional_id
    FROM public.service_conversations
    WHERE request_id = p_request_id::text
      AND professional_id IS DISTINCT FROM p_professional_id
  LOOP
    PERFORM public.notify_service_inbox(
      other.professional_id,
      'NOT_SELECTED',
      'La solicitud ya fue asignada',
      'El cliente eligió a otro profesional para este servicio.',
      NULL,
      jsonb_build_object('request_id', p_request_id)
    );
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'conversation_id', conv_id);
END;
$$;

REVOKE ALL ON FUNCTION public.select_professional_for_request(bigint, bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.select_professional_for_request(bigint, bigint, text) TO authenticated;
REVOKE ALL ON FUNCTION public.notify_service_inbox(text, text, text, text, text, jsonb) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.append_service_system_event(
  p_request_id text,
  p_event text,
  p_content text,
  p_mode text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_professional_id text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
  conv record;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  FOR conv IN
    SELECT *
    FROM public.service_conversations
    WHERE request_id = p_request_id
      AND (customer_id = uid OR professional_id = uid)
      AND (p_professional_id IS NULL OR professional_id = p_professional_id)
  LOOP
    IF p_mode IS NOT NULL OR p_status IS NOT NULL THEN
      UPDATE public.service_conversations
      SET mode = COALESCE(p_mode, mode),
          status = COALESCE(p_status, status),
          updated_at = now()
      WHERE id = conv.id;
    END IF;

    INSERT INTO public.service_chat_messages (
      conversation_id, sender_id, sender_type, message_type, content, delivery_status, metadata
    ) VALUES (
      conv.id,
      NULL,
      'SYSTEM',
      'SYSTEM',
      p_content,
      'SENT',
      jsonb_build_object(
        'system_event', jsonb_build_object(
          'type', p_event,
          'occurred_at', now()
        )
      )
    );
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.append_service_system_event(text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.append_service_system_event(text, text, text, text, text, text) TO authenticated;
