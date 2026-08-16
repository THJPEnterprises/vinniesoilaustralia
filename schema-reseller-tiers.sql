-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Reseller Tiers
-- Run in Supabase SQL Editor AFTER schema-order-minimum.sql.
--
-- Adds 3 reseller tiers with their own wholesale discount, order
-- minimum, and free-shipping benefit. Each product's price to a given
-- reseller is now computed as rrp_aud * (1 - tier discount%), rather
-- than a single flat wholesale_price_aud for everyone. Admins assign a
-- reseller to a tier manually (Admin → Resellers tab), based on their
-- typical order volume — there's no automatic upgrade.
-- ═══════════════════════════════════════════════════════════

create table if not exists public.tier_settings (
  tier int primary key check (tier in (1, 2, 3)),
  label text not null,
  discount_pct numeric(5,2) not null,   -- reseller's margin, e.g. 35 = 35% off RRP
  min_order_qty int not null,            -- overall order minimum for this tier
  free_shipping boolean not null default false,
  benefits text,                         -- shown on the tier explainer page
  updated_at timestamptz not null default now()
);

insert into public.tier_settings (tier, label, discount_pct, min_order_qty, free_shipping, benefits) values
  (1, 'Tier 1', 35, 10, false, 'Entry-level wholesale pricing — 35% margin off RRP. Minimum order 10 units (any mix of products). Shipping quoted per order.'),
  (2, 'Tier 2', 40, 25, false, 'Higher-volume wholesale pricing — 40% margin off RRP. Minimum order 25 units (any mix of products). Shipping quoted per order.'),
  (3, 'Tier 3', 50, 50, true,  'Our best pricing for high-volume partners — 50% margin off RRP. Minimum order 50 units (any mix of products). Free shipping on every order.')
on conflict (tier) do nothing;

alter table public.tier_settings enable row level security;

create policy "tier_settings: authenticated read"
  on public.tier_settings for select
  using (auth.role() = 'authenticated');

create policy "tier_settings: admin update"
  on public.tier_settings for update
  using (public.is_admin());

-- ─── Reseller tier assignment ───
alter table public.profiles
  add column if not exists tier int not null default 1 references public.tier_settings(tier);

-- (Existing "profiles: admin update all" policy from schema-fix-rls-recursion.sql
-- already covers updating this new column — no new policy needed.)

-- ─── Track which tier an order was placed under (for admin visibility) ───
alter table public.orders
  add column if not exists reseller_tier int;

-- To change a reseller's tier later without the admin UI:
-- update public.profiles set tier = 2 where email = 'reseller@example.com';

-- To adjust a tier's discount, minimum or shipping benefit later without the admin UI:
-- update public.tier_settings set discount_pct = 35, min_order_qty = 10, free_shipping = false where tier = 1;
