-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Admin-only tier pricing reference view
-- Run in Supabase SQL Editor AFTER schema-reseller-tiers.sql.
--
-- Lets you see all 3 tiers' computed wholesale prices per product
-- directly in Table Editor, for your own reference — the live portal
-- computes this on the fly (RRP × tier discount%) and never stores it,
-- so it doesn't otherwise show up anywhere in the database.
--
-- Restricted to admins only: the WHERE public.is_admin() clause means
-- non-admin accounts get zero rows back even though they technically
-- have SELECT grant, and anon (public/unauthenticated) has no grant at
-- all. This is deliberately the opposite of public_pricing — that one
-- is intentionally public-safe, this one is not.
-- ═══════════════════════════════════════════════════════════

create or replace view public.tier_pricing_reference as
select
  wp.sku,
  wp.product_name,
  wp.size,
  wp.rrp_aud,
  t1.discount_pct as tier1_margin_pct,
  round(wp.rrp_aud * (1 - t1.discount_pct / 100), 2) as tier1_price_aud,
  t2.discount_pct as tier2_margin_pct,
  round(wp.rrp_aud * (1 - t2.discount_pct / 100), 2) as tier2_price_aud,
  t3.discount_pct as tier3_margin_pct,
  round(wp.rrp_aud * (1 - t3.discount_pct / 100), 2) as tier3_price_aud
from public.wholesale_prices wp
cross join (select discount_pct from public.tier_settings where tier = 1) t1
cross join (select discount_pct from public.tier_settings where tier = 2) t2
cross join (select discount_pct from public.tier_settings where tier = 3) t3
where public.is_admin();

revoke all on public.tier_pricing_reference from anon;
grant select on public.tier_pricing_reference to authenticated;
