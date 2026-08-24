-- Cancelamentos, política antiabuso e restrição temporária.
-- O backend (timestamps Postgres) é a fonte da verdade.

CREATE TABLE IF NOT EXISTS public.cancellation_policy (
  id integer PRIMARY KEY DEFAULT 1,
  rapid_cancel_enabled boolean NOT NULL DEFAULT true,
  rapid_cancel_window_minutes integer NOT NULL DEFAULT 5,
  rapid_cancel_limit integer NOT NULL DEFAULT 2,
  temporary_restriction_minutes integer NOT NULL DEFAULT 15,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cancellation_policy_singleton CHECK (id = 1)
);

INSERT INTO public.cancellation_policy (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.service_cancellations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id text,
  customer_id uuid,
  professional_id text,
  cancelled_by text NOT NULL,
  request_status_at_cancel text,
  reason_code text NOT NULL,
  reason_text text,
  counts_toward_rapid_cancel boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb
);

CREATE TABLE IF NOT EXISTS public.user_restrictions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  restriction_type text NOT NULL,
  reason text,
  starts_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  active boolean NOT NULL DEFAULT true,
  source text,
  created_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb
);

CREATE INDEX IF NOT EXISTS service_cancellations_customer_created
  ON public.service_cancellations (customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS user_restrictions_user_active
  ON public.user_restrictions (user_id, active, expires_at);

ALTER TABLE public.cancellation_policy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_cancellations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_restrictions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS nee_policy_select ON public.cancellation_policy;
CREATE POLICY nee_policy_select ON public.cancellation_policy
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS nee_cancels_select_own ON public.service_cancellations;
CREATE POLICY nee_cancels_select_own ON public.service_cancellations
  FOR SELECT TO authenticated
  USING (customer_id = auth.uid());

DROP POLICY IF EXISTS nee_cancels_insert_own ON public.service_cancellations;
CREATE POLICY nee_cancels_insert_own ON public.service_cancellations
  FOR INSERT TO authenticated
  WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS nee_restrict_select_own ON public.user_restrictions;
CREATE POLICY nee_restrict_select_own ON public.user_restrictions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.apply_rapid_cancel_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  policy public.cancellation_policy%ROWTYPE;
  hits integer;
  until_at timestamptz;
BEGIN
  IF NEW.counts_toward_rapid_cancel IS NOT TRUE OR NEW.customer_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO policy FROM public.cancellation_policy WHERE id = 1;
  IF NOT FOUND OR policy.rapid_cancel_enabled IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*) INTO hits
  FROM public.service_cancellations
  WHERE customer_id = NEW.customer_id
    AND counts_toward_rapid_cancel = true
    AND created_at >= (clock_timestamp() - make_interval(mins => policy.rapid_cancel_window_minutes));

  IF hits >= policy.rapid_cancel_limit THEN
    until_at := clock_timestamp() + make_interval(mins => policy.temporary_restriction_minutes);
    INSERT INTO public.user_restrictions (
      user_id, restriction_type, reason, starts_at, expires_at, active, source
    ) VALUES (
      NEW.customer_id,
      'CREATE_SERVICE_TEMPORARILY_BLOCKED',
      'rapid_cancel',
      clock_timestamp(),
      until_at,
      true,
      'system'
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_cancellation_reason_policy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.counts_toward_rapid_cancel := NEW.reason_code NOT IN (
    'PROFESSIONAL_COULD_NOT_PERFORM',
    'PROFESSIONAL_NO_SHOW',
    'PROFESSIONAL_REQUESTED_CANCEL',
    'SAFETY_CONCERN',
    'TECHNICAL_ERROR'
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cancel_reason_policy ON public.service_cancellations;
CREATE TRIGGER trg_cancel_reason_policy
  BEFORE INSERT ON public.service_cancellations
  FOR EACH ROW
  EXECUTE PROCEDURE public.apply_cancellation_reason_policy();

DROP TRIGGER IF EXISTS trg_rapid_cancel_guard ON public.service_cancellations;
CREATE TRIGGER trg_rapid_cancel_guard
  AFTER INSERT ON public.service_cancellations
  FOR EACH ROW
  EXECUTE PROCEDURE public.apply_rapid_cancel_guard();

GRANT SELECT ON public.cancellation_policy TO authenticated;
GRANT SELECT, INSERT ON public.service_cancellations TO authenticated;
GRANT SELECT ON public.user_restrictions TO authenticated;
