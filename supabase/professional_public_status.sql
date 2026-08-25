-- Só expõe disponibilidade quando há linha em professional_operational_status
-- ou um horário real em professional_next_free_at. Sem isso, reported = false.
CREATE OR REPLACE FUNCTION public.professional_public_status(p_professional_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  ops text;
  found_ops boolean := false;
  next_at timestamptz;
  accepting boolean := true;
BEGIN
  SELECT status INTO ops FROM public.professional_operational_status WHERE professional_id = p_professional_id;
  found_ops := FOUND;
  next_at := public.professional_next_free_at(p_professional_id);

  IF NOT found_ops AND next_at IS NULL THEN
    RETURN jsonb_build_object(
      'reported', false,
      'status', 'OFFLINE',
      'accepting_requests', false,
      'next_available_at', NULL,
      'label_code', 'UNKNOWN'
    );
  END IF;

  ops := COALESCE(ops, 'AVAILABLE');
  IF ops IN ('OFFLINE', 'PAUSED') THEN
    accepting := false;
  END IF;
  IF next_at IS NULL THEN
    RETURN jsonb_build_object(
      'reported', true,
      'status', ops,
      'accepting_requests', accepting,
      'next_available_at', NULL,
      'label_code', CASE WHEN ops = 'PAUSED' THEN 'NOT_ACCEPTING' ELSE 'UNAVAILABLE' END
    );
  END IF;
  IF next_at > now() + interval '2 minutes' THEN
    RETURN jsonb_build_object(
      'reported', true,
      'status', 'BUSY',
      'accepting_requests', accepting,
      'next_available_at', next_at,
      'label_code', 'BUSY_UNTIL'
    );
  END IF;
  RETURN jsonb_build_object(
    'reported', true,
    'status', 'AVAILABLE',
    'accepting_requests', accepting,
    'next_available_at', next_at,
    'label_code', 'AVAILABLE_NOW'
  );
END;
$function$;
