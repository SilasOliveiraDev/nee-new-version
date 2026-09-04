-- Notificaciones cruzadas cliente ↔ profesional.
-- Central: public.notifications (pantalla Notificaciones).
-- Mensaje nuevo avisa al otro. Cambio de solicitud / evento de servicio también.

CREATE OR REPLACE FUNCTION public.notify_pref_allows(p_user_id text, p_pref text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  allowed boolean := true;
BEGIN
  IF p_user_id IS NULL OR p_pref IS NULL OR p_pref NOT IN (
    'chat_messages',
    'request_updates',
    'new_offers',
    'professional_on_the_way',
    'service_started',
    'service_finished'
  ) THEN
    RETURN true;
  END IF;
  IF to_regclass('public.notification_preferences') IS NULL THEN
    RETURN true;
  END IF;
  EXECUTE format(
    'SELECT coalesce(%I, true) FROM public.notification_preferences WHERE user_id = $1',
    p_pref
  )
  INTO allowed
  USING p_user_id;
  RETURN coalesce(allowed, true);
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_app_notice(
  p_user_id text,
  p_title text,
  p_message text,
  p_type text,
  p_category text,
  p_action_type text,
  p_action_target text,
  p_related_id text,
  p_related_entity_type text DEFAULT NULL,
  p_preview text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_pref text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_user_id IS NULL OR btrim(p_user_id) = '' THEN
    RETURN;
  END IF;
  IF p_pref IS NOT NULL AND NOT public.notify_pref_allows(p_user_id, p_pref) THEN
    RETURN;
  END IF;

  INSERT INTO public.notifications (
    user_id,
    title,
    message,
    type,
    category,
    action_type,
    action_target,
    related_id,
    related_entity_id,
    related_entity_type,
    preview,
    metadata,
    is_read,
    is_active
  ) VALUES (
    p_user_id,
    p_title,
    p_message,
    p_type,
    p_category,
    p_action_type,
    p_action_target,
    p_related_id,
    p_related_id,
    p_related_entity_type,
    COALESCE(p_preview, left(p_message, 140)),
    p_metadata,
    false,
    true
  );
END;
$$;

REVOKE ALL ON FUNCTION public.notify_app_notice(
  text, text, text, text, text, text, text, text, text, text, jsonb, text
) FROM PUBLIC;

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
DECLARE
  v_category text := 'SERVICE';
  v_action text := 'SYSTEM';
  v_target text := 'SERVICE_DETAIL';
  v_pref text := 'request_updates';
  v_related text;
  v_entity text := 'SERVICE_REQUEST';
BEGIN
  INSERT INTO public.service_inbox (user_id, kind, title, body, cta, payload)
  VALUES (p_user_id, p_kind, p_title, p_body, p_cta, p_payload);

  v_related := COALESCE(
    p_payload ->> 'conversation_id',
    p_payload ->> 'request_id',
    p_payload ->> 'service_id'
  );

  CASE upper(p_kind)
    WHEN 'DIRECT_REQUEST' THEN
      v_action := 'SYSTEM';
      v_target := 'SERVICE_DETAIL';
    WHEN 'DIRECT_ACCEPTED' THEN
      v_action := 'PROFESSIONAL_CONFIRMED';
      v_target := 'CONVERSATION';
    WHEN 'DIRECT_DECLINED' THEN
      v_action := 'SERVICE_CANCELLED';
      v_target := 'SERVICE_HISTORY';
    WHEN 'SERVICE_CONFIRMED' THEN
      v_action := 'PROFESSIONAL_CONFIRMED';
      v_target := 'ACTIVE_SERVICE';
    WHEN 'PROFESSIONAL_SELECTED' THEN
      v_action := 'PROFESSIONAL_CONFIRMED';
      v_target := 'ACTIVE_SERVICE';
    WHEN 'NOT_SELECTED' THEN
      v_action := 'SYSTEM';
      v_target := 'NOTIFICATION_DETAIL';
    WHEN 'FINAL_PROPOSAL' THEN
      v_category := 'OFFER';
      v_action := 'NEW_OFFER';
      v_target := 'SERVICE_OFFER';
      v_pref := 'new_offers';
    ELSE
      v_action := 'SYSTEM';
  END CASE;

  IF (p_payload ->> 'conversation_id') IS NOT NULL AND v_target = 'CONVERSATION' THEN
    v_related := p_payload ->> 'conversation_id';
    v_entity := 'CONVERSATION';
  END IF;

  PERFORM public.notify_app_notice(
    p_user_id,
    p_title,
    p_body,
    lower(p_kind),
    v_category,
    v_action,
    v_target,
    v_related,
    v_entity,
    left(p_body, 140),
    p_payload,
    v_pref
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_new_proposal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  payload json;
  v_client text;
  v_title text;
  v_pro_first text;
  v_body text;
BEGIN
  payload := json_build_object(
    'id', new.id,
    'created_at', new.created_at,
    'professional_id', new.professional_id,
    'service_request_id', new.service_request_id,
    'proposal_message', new.proposal_message,
    'price_estimate', new.price_estimate,
    'time_estimate', new.time_estimate,
    'status', new.status,
    'idCliente', new."idCliente",
    'IsDestaque', new."IsDestaque"
  );

  BEGIN
    PERFORM http_post(
      'https://notifications-n8n.ael8y8.easypanel.host/webhook/receber-propostas',
      payload::text,
      'application/json'
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Falha ao enviar webhook, mas proposta foi salva.';
  END;

  BEGIN
    SELECT COALESCE(NULLIF(btrim(new."idCliente"), ''), sr.client_id),
           COALESCE(NULLIF(btrim(sr.title), ''), NULLIF(btrim(sr.categoria), ''), 'tu solicitud')
      INTO v_client, v_title
    FROM public.service_requests sr
    WHERE sr.id::text = new.service_request_id
    LIMIT 1;

    v_client := COALESCE(NULLIF(btrim(v_client), ''), NULLIF(btrim(new."idCliente"), ''));

    IF v_client IS NOT NULL
       AND v_client <> ''
       AND v_client IS DISTINCT FROM new.professional_id THEN
      SELECT NULLIF(split_part(trim(name), ' ', 1), '')
        INTO v_pro_first
      FROM public.users
      WHERE "UUID"::text = new.professional_id
      LIMIT 1;

      IF v_pro_first IS NULL OR v_pro_first = '' THEN
        v_body := 'Un profesional envió una propuesta para «' || COALESCE(v_title, 'tu solicitud') || '».';
      ELSE
        v_body := v_pro_first || ' envió una propuesta para «' || COALESCE(v_title, 'tu solicitud') || '».';
      END IF;

      PERFORM public.notify_app_notice(
        v_client,
        'Nueva propuesta',
        v_body,
        'propuesta',
        'OFFER',
        'NEW_OFFER',
        'SERVICE_OFFER',
        new.service_request_id,
        'SERVICE_REQUEST',
        NULLIF(left(btrim(COALESCE(new.proposal_message, '')), 140), ''),
        jsonb_build_object(
          'proposal_id', new.id,
          'request_id', new.service_request_id,
          'professional_id', new.professional_id
        ),
        'new_offers'
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'No se pudo crear la notificación de propuesta.';
  END;

  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_counterpart_chat_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  conv public.service_conversations%ROWTYPE;
  v_recipient text;
  v_sender_first text;
  v_title text := 'Nuevo mensaje';
  v_body text;
  v_preview text;
  v_updated int;
BEGIN
  IF new.sender_type IS NULL OR upper(new.sender_type) = 'SYSTEM' THEN
    RETURN new;
  END IF;
  IF new.deleted_at IS NOT NULL THEN
    RETURN new;
  END IF;

  SELECT * INTO conv
  FROM public.service_conversations
  WHERE id = new.conversation_id;

  IF NOT FOUND THEN
    RETURN new;
  END IF;

  IF upper(new.sender_type) = 'PROFESSIONAL' THEN
    v_recipient := conv.customer_id;
  ELSIF upper(new.sender_type) = 'CUSTOMER' THEN
    v_recipient := conv.professional_id;
  ELSE
    RETURN new;
  END IF;

  IF v_recipient IS NULL
     OR btrim(v_recipient) = ''
     OR v_recipient IS NOT DISTINCT FROM new.sender_id THEN
    RETURN new;
  END IF;

  SELECT NULLIF(split_part(trim(name), ' ', 1), '')
    INTO v_sender_first
  FROM public.users
  WHERE "UUID"::text = COALESCE(new.sender_id, '')
  LIMIT 1;

  IF v_sender_first IS NOT NULL AND v_sender_first <> '' THEN
    v_title := 'Nuevo mensaje de ' || v_sender_first;
  END IF;

  IF upper(COALESCE(new.message_type, 'TEXT')) = 'IMAGE' THEN
    v_preview := 'Foto';
    IF v_sender_first IS NULL OR v_sender_first = '' THEN
      v_body := 'Te envió una foto.';
    ELSE
      v_body := v_sender_first || ' te envió una foto.';
    END IF;
  ELSE
    v_preview := NULLIF(left(btrim(COALESCE(new.content, '')), 140), '');
    IF v_preview IS NULL THEN
      v_body := COALESCE(v_sender_first, 'Ñee') || ' te envió un mensaje.';
    ELSE
      v_body := v_preview;
    END IF;
  END IF;

  UPDATE public.notifications
  SET
    title = v_title,
    message = v_body,
    preview = COALESCE(v_preview, left(v_body, 140)),
    created_at = now(),
    is_read = false,
    read_at = null,
    metadata = jsonb_build_object(
      'conversation_id', conv.id,
      'request_id', conv.request_id,
      'message_id', new.id
    )
  WHERE user_id = v_recipient
    AND action_type = 'NEW_MESSAGE'
    AND related_entity_id = conv.id::text
    AND COALESCE(is_read, false) = false
    AND created_at > now() - interval '3 minutes';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    PERFORM public.notify_app_notice(
      v_recipient,
      v_title,
      v_body,
      'mensaje',
      'MESSAGE',
      'NEW_MESSAGE',
      'CONVERSATION',
      conv.id::text,
      'CONVERSATION',
      v_preview,
      jsonb_build_object(
        'conversation_id', conv.id,
        'request_id', conv.request_id,
        'message_id', new.id
      ),
      'chat_messages'
    );
  END IF;

  RETURN new;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'No se pudo notificar el mensaje nuevo.';
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_counterpart_chat_message ON public.service_chat_messages;
CREATE TRIGGER trg_notify_counterpart_chat_message
AFTER INSERT ON public.service_chat_messages
FOR EACH ROW
EXECUTE FUNCTION public.notify_counterpart_chat_message();

CREATE OR REPLACE FUNCTION public.notify_counterpart_request_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor text := auth.uid()::text;
  v_client text := NEW.client_id;
  v_pro text := COALESCE(
    NEW.selected_professional_id,
    NEW.profissional_id,
    NEW.target_professional_id
  );
  v_recipient text;
  v_title text;
  v_body text;
  v_action text := 'SYSTEM';
  v_target text := 'SERVICE_DETAIL';
  v_pref text := 'request_updates';
  v_status text := lower(coalesce(NEW.status, ''));
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF actor IS NOT NULL AND actor IS NOT DISTINCT FROM v_client THEN
    v_recipient := v_pro;
  ELSIF actor IS NOT NULL AND actor IS NOT DISTINCT FROM v_pro THEN
    v_recipient := v_client;
  ELSIF actor IS NULL THEN
    RETURN NEW;
  ELSE
    IF actor IS DISTINCT FROM v_client THEN
      v_recipient := v_client;
    ELSE
      v_recipient := v_pro;
    END IF;
  END IF;

  IF v_recipient IS NULL OR btrim(v_recipient) = '' OR v_recipient IS NOT DISTINCT FROM actor THEN
    RETURN NEW;
  END IF;

  IF v_status LIKE '%camino%' THEN
    v_title := 'El profesional está en camino';
    v_body := 'Ya salió hacia el lugar del servicio.';
    v_action := 'PROFESSIONAL_ON_THE_WAY';
    v_target := 'ACTIVE_SERVICE';
    v_pref := 'professional_on_the_way';
  ELSIF v_status LIKE '%lleg%' THEN
    v_title := 'El profesional llegó';
    v_body := 'Está en el lugar del servicio.';
    v_action := 'PROFESSIONAL_ARRIVED';
    v_target := 'ACTIVE_SERVICE';
  ELSIF v_status LIKE '%curso%' OR v_status LIKE '%progreso%' THEN
    v_title := 'Servicio iniciado';
    v_body := 'El trabajo ya está en curso.';
    v_action := 'SERVICE_STARTED';
    v_target := 'ACTIVE_SERVICE';
    v_pref := 'service_started';
  ELSIF v_status LIKE '%final%' OR v_status LIKE '%complet%' THEN
    v_title := 'Servicio finalizado';
    v_body := 'Ya puedes calificar el trabajo.';
    v_action := 'SERVICE_FINISHED';
    v_target := 'SERVICE_DETAIL';
    v_pref := 'service_finished';
  ELSIF v_status LIKE '%cancel%' THEN
    v_title := 'Servicio cancelado';
    v_body := COALESCE(NULLIF(btrim(NEW.status), ''), 'La solicitud fue cancelada.');
    v_action := 'SERVICE_CANCELLED';
    v_target := 'SERVICE_HISTORY';
  ELSIF v_status LIKE '%seleccion%' THEN
    v_title := 'Profesional seleccionado';
    v_body := 'El cliente te eligió para este servicio.';
    v_action := 'PROFESSIONAL_CONFIRMED';
    v_target := 'ACTIVE_SERVICE';
  ELSIF v_status LIKE '%convers%' OR v_status LIKE '%acept%' THEN
    v_title := 'Hay una novedad en tu solicitud';
    v_body := COALESCE(NULLIF(btrim(NEW.status), ''), 'El estado del servicio cambió.');
    v_action := 'PROFESSIONAL_CONFIRMED';
    v_target := 'CONVERSATION';
  ELSE
    v_title := 'Actualización del servicio';
    v_body := COALESCE(NULLIF(btrim(NEW.status), ''), 'Hay un cambio en la solicitud.');
  END IF;

  PERFORM public.notify_app_notice(
    v_recipient,
    v_title,
    v_body,
    'servicio',
    'SERVICE',
    v_action,
    v_target,
    NEW.id::text,
    'SERVICE_REQUEST',
    left(v_body, 140),
    jsonb_build_object(
      'request_id', NEW.id,
      'status', NEW.status,
      'actor_id', actor
    ),
    v_pref
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'No se pudo notificar el cambio de solicitud.';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_counterpart_request_status ON public.service_requests;
CREATE TRIGGER trg_notify_counterpart_request_status
AFTER UPDATE OF status ON public.service_requests
FOR EACH ROW
EXECUTE FUNCTION public.notify_counterpart_request_status();

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
  v_recipient text;
  v_title text;
  v_action text := 'SYSTEM';
  v_target text := 'SERVICE_DETAIL';
  v_pref text := 'request_updates';
  v_event text := upper(coalesce(p_event, ''));
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

    IF conv.customer_id IS NOT DISTINCT FROM uid THEN
      v_recipient := conv.professional_id;
    ELSE
      v_recipient := conv.customer_id;
    END IF;

    IF v_event IN ('PROFESSIONAL_ON_THE_WAY') THEN
      v_title := 'El profesional está en camino';
      v_action := 'PROFESSIONAL_ON_THE_WAY';
      v_target := 'ACTIVE_SERVICE';
      v_pref := 'professional_on_the_way';
    ELSIF v_event IN ('PROFESSIONAL_ARRIVED') THEN
      v_title := 'El profesional llegó';
      v_action := 'PROFESSIONAL_ARRIVED';
      v_target := 'ACTIVE_SERVICE';
    ELSIF v_event IN ('SERVICE_STARTED') THEN
      v_title := 'Servicio iniciado';
      v_action := 'SERVICE_STARTED';
      v_target := 'ACTIVE_SERVICE';
      v_pref := 'service_started';
    ELSIF v_event IN ('SERVICE_FINISHED', 'SERVICE_COMPLETED') THEN
      v_title := 'Servicio finalizado';
      v_action := 'SERVICE_FINISHED';
      v_target := 'SERVICE_DETAIL';
      v_pref := 'service_finished';
    ELSIF v_event IN ('SERVICE_CANCELLED', 'SERVICE_NOT_COMPLETED') THEN
      v_title := 'Servicio cancelado';
      v_action := 'SERVICE_CANCELLED';
      v_target := 'SERVICE_HISTORY';
    ELSE
      v_title := COALESCE(NULLIF(btrim(p_content), ''), 'Actualización del servicio');
    END IF;

    IF v_recipient IS NOT NULL AND v_recipient IS DISTINCT FROM uid THEN
      PERFORM public.notify_app_notice(
        v_recipient,
        v_title,
        COALESCE(NULLIF(btrim(p_content), ''), v_title),
        'servicio',
        'SERVICE',
        v_action,
        v_target,
        conv.request_id,
        'SERVICE_REQUEST',
        left(COALESCE(p_content, v_title), 140),
        jsonb_build_object(
          'request_id', conv.request_id,
          'conversation_id', conv.id,
          'event', p_event
        ),
        v_pref
      );
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.append_service_system_event(text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.append_service_system_event(text, text, text, text, text, text) TO authenticated;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS nee_notifications_select ON public.notifications;
CREATE POLICY nee_notifications_select ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text);

DROP POLICY IF EXISTS nee_notifications_update ON public.notifications;
CREATE POLICY nee_notifications_update ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);

GRANT SELECT, UPDATE ON public.notifications TO authenticated;

ALTER TABLE public.notifications REPLICA IDENTITY FULL;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END;
$$;
