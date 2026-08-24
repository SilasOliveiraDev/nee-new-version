-- Central de notificaciones: categoría, destino y lectura.
alter table public.notifications
  add column if not exists category text,
  add column if not exists preview text,
  add column if not exists related_entity_type text,
  add column if not exists related_entity_id text,
  add column if not exists action_type text,
  add column if not exists action_target text,
  add column if not exists read_at timestamptz;

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc)
  where coalesce(is_active, true);

create index if not exists notifications_user_category_created_idx
  on public.notifications (user_id, category, created_at desc)
  where coalesce(is_active, true);
