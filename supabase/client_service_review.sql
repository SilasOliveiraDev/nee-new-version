-- Evaluación por criterios (1–5 estrellas) al terminar un servicio.

ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS request_id bigint,
  ADD COLUMN IF NOT EXISTS rating_quality smallint,
  ADD COLUMN IF NOT EXISTS rating_conduct smallint,
  ADD COLUMN IF NOT EXISTS rating_ethics smallint,
  ADD COLUMN IF NOT EXISTS rating_courtesy smallint,
  ADD COLUMN IF NOT EXISTS rating_punctuality smallint;

ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_quality_range;
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_conduct_range;
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_ethics_range;
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_courtesy_range;
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_punctuality_range;

ALTER TABLE public.reviews
  ADD CONSTRAINT reviews_quality_range
    CHECK (rating_quality IS NULL OR rating_quality BETWEEN 1 AND 5),
  ADD CONSTRAINT reviews_conduct_range
    CHECK (rating_conduct IS NULL OR rating_conduct BETWEEN 1 AND 5),
  ADD CONSTRAINT reviews_ethics_range
    CHECK (rating_ethics IS NULL OR rating_ethics BETWEEN 1 AND 5),
  ADD CONSTRAINT reviews_courtesy_range
    CHECK (rating_courtesy IS NULL OR rating_courtesy BETWEEN 1 AND 5),
  ADD CONSTRAINT reviews_punctuality_range
    CHECK (rating_punctuality IS NULL OR rating_punctuality BETWEEN 1 AND 5);

CREATE UNIQUE INDEX IF NOT EXISTS reviews_request_client_uidx
  ON public.reviews (request_id, cliente_id)
  WHERE request_id IS NOT NULL AND cliente_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.submit_client_review(
  p_request_id bigint,
  p_quality integer,
  p_conduct integer,
  p_ethics integer,
  p_courtesy integer,
  p_punctuality integer,
  p_comment text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid text := auth.uid()::text;
  req public.service_requests%ROWTYPE;
  pro_id text;
  overall double precision;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  IF p_quality NOT BETWEEN 1 AND 5
     OR p_conduct NOT BETWEEN 1 AND 5
     OR p_ethics NOT BETWEEN 1 AND 5
     OR p_courtesy NOT BETWEEN 1 AND 5
     OR p_punctuality NOT BETWEEN 1 AND 5 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'INVALID_SCORES');
  END IF;

  SELECT * INTO req FROM public.service_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND');
  END IF;
  IF req.client_id IS DISTINCT FROM uid THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF COALESCE(req.status, '') ~* '(cancel|expir|no se pudo)' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'CLOSED');
  END IF;

  pro_id := COALESCE(
    req.selected_professional_id,
    req.profissional_id,
    req.target_professional_id
  );
  IF pro_id IS NULL OR btrim(pro_id) = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NO_PROFESSIONAL');
  END IF;

  overall := round(
    ((p_quality + p_conduct + p_ethics + p_courtesy + p_punctuality)::numeric / 5),
    1
  );

  UPDATE public.reviews
  SET rating = overall,
      rating_quality = p_quality,
      rating_conduct = p_conduct,
      rating_ethics = p_ethics,
      rating_courtesy = p_courtesy,
      rating_punctuality = p_punctuality,
      comment = NULLIF(btrim(COALESCE(p_comment, '')), ''),
      profissional_id = pro_id,
      created_at = now()
  WHERE request_id = p_request_id
    AND cliente_id = uid;

  IF NOT FOUND THEN
    INSERT INTO public.reviews (
      service_id,
      request_id,
      cliente_id,
      profissional_id,
      rating,
      rating_quality,
      rating_conduct,
      rating_ethics,
      rating_courtesy,
      rating_punctuality,
      comment,
      is_visible
    ) VALUES (
      p_request_id::text,
      p_request_id,
      uid,
      pro_id,
      overall,
      p_quality,
      p_conduct,
      p_ethics,
      p_courtesy,
      p_punctuality,
      NULLIF(btrim(COALESCE(p_comment, '')), ''),
      true
    );
  END IF;

  UPDATE public.users
  SET "rateAvaliacao" = (
    SELECT avg(r.rating)
    FROM public.reviews r
    WHERE r.profissional_id = pro_id
      AND COALESCE(r.is_visible, true)
      AND r.rating IS NOT NULL
  )
  WHERE "UUID"::text = pro_id;

  UPDATE public.service_requests
  SET status = 'Finalizado',
      disponivel = false
  WHERE id = p_request_id;

  RETURN jsonb_build_object('ok', true, 'rating', overall);
END;
$$;

REVOKE ALL ON FUNCTION public.submit_client_review(bigint, integer, integer, integer, integer, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_client_review(bigint, integer, integer, integer, integer, integer, text) TO authenticated;
