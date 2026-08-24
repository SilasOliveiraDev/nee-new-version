-- Liga proposals ao cliente e à solicitação que já existem.
-- Fonte da verdade: service_requests.id + service_requests.client_id.

UPDATE public.proposals AS p
SET "idCliente" = sr.client_id
FROM public.service_requests AS sr
WHERE p.service_request_id = sr.id::text
  AND sr.client_id IS NOT NULL
  AND btrim(sr.client_id) <> '';

UPDATE public.service_requests AS sr
SET
  "idPropostas" = sub.ids,
  "qtdPropostas" = sub.cnt
FROM (
  SELECT
    p.service_request_id,
    array_agg(p.id::text ORDER BY p.id) AS ids,
    COUNT(*)::double precision AS cnt
  FROM public.proposals AS p
  GROUP BY p.service_request_id
) AS sub
WHERE sr.id::text = sub.service_request_id;

CREATE INDEX IF NOT EXISTS proposals_service_request_id_idx
  ON public.proposals (service_request_id);
CREATE INDEX IF NOT EXISTS proposals_id_cliente_idx
  ON public.proposals ("idCliente");
CREATE INDEX IF NOT EXISTS proposals_professional_id_idx
  ON public.proposals (professional_id);

CREATE OR REPLACE FUNCTION public.fill_proposal_client_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.service_request_id IS NOT NULL THEN
    SELECT sr.client_id
      INTO NEW."idCliente"
    FROM public.service_requests AS sr
    WHERE sr.id::text = NEW.service_request_id::text
    LIMIT 1;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fill_proposal_client_id ON public.proposals;
CREATE TRIGGER trg_fill_proposal_client_id
  BEFORE INSERT OR UPDATE OF service_request_id
  ON public.proposals
  FOR EACH ROW
  EXECUTE PROCEDURE public.fill_proposal_client_id();

CREATE OR REPLACE FUNCTION public.sync_request_proposal_ids()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rid text;
BEGIN
  rid := COALESCE(NEW.service_request_id, OLD.service_request_id);
  IF rid IS NULL OR btrim(rid) = '' THEN
    RETURN NULL;
  END IF;
  UPDATE public.service_requests
  SET
    "idPropostas" = COALESCE((
      SELECT array_agg(p.id::text ORDER BY p.id)
      FROM public.proposals AS p
      WHERE p.service_request_id = rid
    ), '{}'),
    "qtdPropostas" = (
      SELECT COUNT(*)::double precision
      FROM public.proposals AS p
      WHERE p.service_request_id = rid
    )
  WHERE id::text = rid;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_request_proposal_ids ON public.proposals;
CREATE TRIGGER trg_sync_request_proposal_ids
  AFTER INSERT OR UPDATE OF service_request_id OR DELETE
  ON public.proposals
  FOR EACH ROW
  EXECUTE PROCEDURE public.sync_request_proposal_ids();

CREATE OR REPLACE FUNCTION public.sync_proposals_from_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.client_id IS DISTINCT FROM OLD.client_id THEN
    UPDATE public.proposals
    SET "idCliente" = NEW.client_id
    WHERE service_request_id = NEW.id::text;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_proposals_from_request ON public.service_requests;
CREATE TRIGGER trg_sync_proposals_from_request
  AFTER UPDATE OF client_id
  ON public.service_requests
  FOR EACH ROW
  EXECUTE PROCEDURE public.sync_proposals_from_request();

DROP POLICY IF EXISTS nee_users_select_proposal_pros ON public.users;
CREATE POLICY nee_users_select_proposal_pros ON public.users
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.proposals AS p
      WHERE p.professional_id = "UUID"::text
        AND p."idCliente" = auth.uid()::text
    )
  );
