-- Perfil público de profissionais (user_type = Servicio). Sem e-mail, telefone completo ou documentos.
-- phone_masked oculta os últimos 4 dígitos. O número completo só sai pelo RPC
-- professional_whatsapp_number quando o profissional é verificado.
-- Rode no SQL Editor do Supabase para a Home destacar verified=true.
create or replace view public.professional_public_profiles as
select
  u."UUID"::text as professional_id,
  u.name as display_name,
  u."imagemPerfil" as avatar_url,
  u."user_type" as user_type,
  coalesce(
    cat_id.nome,
    (
      select c.nome
      from public.categories c
      where u."categoriaId" is null
        and nullif(btrim(coalesce(u."Categoria", '')), '') is not null
        and lower(btrim(u."Categoria")) !~ '(anillo|plan 3000|distrito|equipetrol)'
        and lower(btrim(c.nome)) = lower(btrim(u."Categoria"))
      order by c.id
      limit 1
    ),
    case
      when lower(btrim(coalesce(u."Categoria", ''))) ~ '(anillo|plan 3000|distrito|equipetrol)'
        then null
      else nullif(btrim(u."Categoria"), '')
    end
  ) as category_name,
  coalesce(
    u."categoriaId",
    (
      select c.id
      from public.categories c
      where u."categoriaId" is null
        and nullif(btrim(coalesce(u."Categoria", '')), '') is not null
        and lower(btrim(u."Categoria")) !~ '(anillo|plan 3000|distrito|equipetrol)'
        and lower(btrim(c.nome)) = lower(btrim(u."Categoria"))
      order by c.id
      limit 1
    )
  ) as category_id,
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
  u."statusDocumentos" as document_status,
  coalesce(u.verified, false) as verified,
  (
    select case
      when local = '' then null
      when length(local) <= 4 then '+591 ••••'
      else '+591 ' || left(local, length(local) - 4) || ' ••••'
    end
    from (
      select regexp_replace(
        regexp_replace(coalesce(u.phone, ''), '\D', '', 'g'),
        '^591',
        ''
      ) as local
    ) s
  ) as phone_masked
from public.users u
left join public.categories cat_id on cat_id.id = u."categoriaId"
where u."user_type" = 'Servicio'
  and coalesce(u."isDeletado", false) is not true;

grant select on public.professional_public_profiles to anon, authenticated;
