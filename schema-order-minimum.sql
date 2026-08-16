-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Overall order minimum (replaces per-product MOQ)
-- Run in Supabase SQL Editor AFTER schema-admin-extras.sql.
--
-- Previously each product's own min_order_qty blocked a reseller from
-- ordering, e.g., 2 of one item + 3 of another even though the total (5)
-- was reasonable. This replaces that with a single overall minimum that
-- applies to the TOTAL quantity across the whole order, any mix of
-- products. Individual products can still be ordered in any quantity
-- (including 1) as long as the order as a whole meets the minimum.
-- ═══════════════════════════════════════════════════════════

create table if not exists public.order_settings (
  id int primary key default 1,
  min_order_qty int not null default 10,
  updated_at timestamptz not null default now(),
  constraint order_settings_singleton check (id = 1)
);

insert into public.order_settings (id, min_order_qty)
values (1, 10)
on conflict (id) do nothing;

alter table public.order_settings enable row level security;

-- Any authenticated (approved) reseller needs to read this to validate
-- their order before submitting.
create policy "order_settings: authenticated read"
  on public.order_settings for select
  using (auth.role() = 'authenticated');

-- Only admins can change it.
create policy "order_settings: admin update"
  on public.order_settings for update
  using (public.is_admin());

-- To change the minimum later without the admin UI:
-- update public.order_settings set min_order_qty = 10 where id = 1;
