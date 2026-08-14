-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Admin pricing/user management extras
-- Run in Supabase SQL Editor AFTER schema-fix-rls-recursion.sql.
-- ═══════════════════════════════════════════════════════════

-- ─── ADMIN CAN MANAGE WHOLESALE PRICING ───
-- Previously only SELECT (approved users) existed. Admins can now also
-- add/edit/delete products and pricing from the admin UI.
create policy "wholesale_prices: admin insert"
  on public.wholesale_prices for insert
  with check (public.is_admin());

create policy "wholesale_prices: admin update"
  on public.wholesale_prices for update
  using (public.is_admin());

create policy "wholesale_prices: admin delete"
  on public.wholesale_prices for delete
  using (public.is_admin());

-- ─── PUBLIC RRP VIEW (for the public website's product pages) ───
-- Product pages show a Recommended Retail Price to anyone, not just
-- logged-in resellers — but wholesale_price_aud must stay private
-- (that's your cost price to resellers, not for public eyes). This view
-- exposes only the safe columns and is granted to the anon role, so
-- public pages can read it without authentication while wholesale_prices
-- itself stays behind the "approved reseller" RLS policy.
create or replace view public.public_pricing as
  select sku, product_name, size, rrp_aud
  from public.wholesale_prices;

grant select on public.public_pricing to anon, authenticated;

-- ─── MAKE YOURSELF AN ADMIN (reminder — same as before) ───
-- update public.profiles set role = 'admin', approved = true
-- where email = 'your-admin-email@example.com';
