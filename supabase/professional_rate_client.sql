ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS author_role text NOT NULL DEFAULT 'CUSTOMER';

CREATE UNIQUE INDEX IF NOT EXISTS reviews_professional_rates_client_uidx
  ON public.reviews (service_id, profissional_id)
  WHERE author_role = 'PROFESSIONAL' AND service_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.professional_rate_client(
  p_request_id bigint,
  p_rating int,
  p_comment text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
  req public.service_requests%ROWTYPE;
  assigned text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'INVALID_RATING');
  END IF;

  SELECT * INTO req FROM public.service_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND');
  END IF;

  assigned := COALESCE(req.selected_professional_id, req.profissional_id, req.target_professional_id);
  IF assigned IS DISTINCT FROM uid THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF COALESCE(req.status, '') !~* '(final|complet)' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_FINISHED');
  END IF;

  IF req.client_id IS NULL OR btrim(req.client_id) = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NO_CLIENT');
  END IF;

  UPDATE public.reviews
  SET rating = p_rating,
      comment = NULLIF(btrim(COALESCE(p_comment, '')), ''),
      created_at = now()
  WHERE service_id = p_request_id::text
    AND profissional_id = uid
    AND author_role = 'PROFESSIONAL';

  IF NOT FOUND THEN
    INSERT INTO public.reviews (
      service_id, cliente_id, profissional_id, rating, comment, is_visible, author_role
    ) VALUES (
      p_request_id::text,
      req.client_id,
      uid,
      p_rating,
      NULLIF(btrim(COALESCE(p_comment, '')), ''),
      true,
      'PROFESSIONAL'
    );
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION public.professional_rate_client(bigint, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.professional_rate_client(bigint, int, text) TO authenticated;
