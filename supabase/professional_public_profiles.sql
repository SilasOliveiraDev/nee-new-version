-- Perfil público de profissionais (user_type = Servicio). Sem e-mail, telefone ou documentos.
-- Rode no SQL Editor do Supabase para a Home separar verified.
create or replace view public.professional_public_profiles as
select
  u."UUID"::text as professional_id,
  u.name as display_name,
  u."imagemPerfil" as avatar_url,
  u."user_type" as user_type,
  cat.nome as category_name,
  u."categoriaId" as category_id,
  u."Subcategoria" as specialty,
  u."descricaoSobre" as bio,
  u."Zona" as zone,
  coalesce(nullif(btrim(coalesce(u.cidade, '')), ''), nullif(btrim(coalesce(u.city, '')), '')) as city,
  u.zona_atendimento as service_area,
  u.latlng,
  (
    select avg(r.rating)
    from public.reviews r
    where r.profissional_id = u."UUID"::text
      and coalesce(r.is_visible, true)
      and r.rating is not null
  ) as reviews_average,
  coalesce(u."rateAvaliacao", 0) as stored_rating,
  (
    select count(*)::int
    from public.reviews r
    where r.profissional_id = u."UUID"::text
      and coalesce(r.is_visible, true)
      and r.rating is not null
  ) as rating_count,
  (
    select count(*)::int
    from public.service_requests sr
    where (sr.profissional_id = u."UUID"::text
        or sr.selected_professional_id = u."UUID"::text)
      and sr.status in ('Finalizado', 'COMPLETED', 'completed')
  ) as completed_jobs_count,
  coalesce(u."isDestacado", false) as is_featured,
  coalesce(u."isSuspenso", false) as is_suspended,
  coalesce(u."isBloqueado", false) as is_blocked,
  coalesce(u.verified, false) as verified,
  u."statusDocumentos" as document_status
from public.users u
left join public.categories cat on cat.id = u."categoriaId"
where u."user_type" = 'Servicio'
  and coalesce(u."isDeletado", false) is not true;

grant select on public.professional_public_profiles to anon, authenticated;
