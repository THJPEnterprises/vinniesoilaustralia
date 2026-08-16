-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Gold (Tier 3) rename + new Platinum (Tier 4)
-- Run in Supabase SQL Editor AFTER schema-reseller-tiers.sql.
--
-- Renames Tier 3 to "Gold" and drops its margin from 50% to 45%. Adds a
-- new Tier 4 "Platinum" at 50% margin, 100-unit per-order minimum.
-- Platinum's real qualifying criteria — quarterly order volume of 50+
-- units — isn't something the system tracks automatically (tiers are
-- still assigned manually by admin, same as before), so it's spelled
-- out in the benefits text shown to resellers instead of being a live
-- gate on the order form.
-- ═══════════════════════════════════════════════════════════

-- Allow tier 4 as a valid value (the column's check constraint was
-- originally defined inline as tier in (1,2,3)).
alter table public.tier_settings drop constraint if exists tier_settings_tier_check;
alter table public.tier_settings add constraint tier_settings_tier_check check (tier in (1, 2, 3, 4));

-- ─── Rename Tier 3 → Gold, 50% → 45% ───
update public.tier_settings
set
  label = 'Gold',
  discount_pct = 45,
  benefits = 'Our high-volume wholesale tier — 45% margin off RRP. Minimum order 50 units (any mix of products). Free shipping on every order.'
where tier = 3;

-- ─── New Tier 4 — Platinum ───
insert into public.tier_settings (tier, label, discount_pct, min_order_qty, free_shipping, benefits)
values (
  4,
  'Platinum',
  50,
  100,
  true,
  E'Our top wholesale tier — 50% margin off RRP. Requires a quarterly order volume of 50+ units to qualify and maintain (reviewed by our team).\n30-Day Account Terms\nPriority Dispatch\nEarly Access to New Product Lines & Limited Runs\n2% Quarterly Volume Rebate (based on paid order amount)\nMarketing Posters & Displays Supplied\nFeatured as a Preferred Partner Stockist on our website'
)
on conflict (tier) do update set
  label = excluded.label,
  discount_pct = excluded.discount_pct,
  min_order_qty = excluded.min_order_qty,
  free_shipping = excluded.free_shipping,
  benefits = excluded.benefits;

-- To adjust any of this later without the admin UI:
-- update public.tier_settings set discount_pct = 50, min_order_qty = 100 where tier = 4;
