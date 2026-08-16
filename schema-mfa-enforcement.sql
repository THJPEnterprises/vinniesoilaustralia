-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Mandatory MFA (TOTP) enforcement
-- Run in Supabase SQL Editor AFTER schema-admin-resources.sql.
--
-- Requires every account (reseller and admin) to complete an
-- authenticator-app (TOTP) challenge before any portal data can be
-- read or written — not just a client-side redirect, but enforced at
-- the database level via Row Level Security, so it can't be bypassed
-- by calling the Supabase API directly with a valid-but-unverified
-- (aal1) session token.
--
-- Supabase Auth's MFA (TOTP) support is built in — no extra service or
-- cost. Enrollment/challenge UI lives on pages/portal-login.html.
-- ═══════════════════════════════════════════════════════════

-- True only once the current session has completed an MFA challenge
-- this session (aal2). False for a plain password-only (aal1) session,
-- and false for anon/no session at all.
create or replace function public.has_mfa()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt() ->> 'aal'), '') = 'aal2';
$$;

-- Fold the aal2 requirement into is_admin() so every existing
-- admin-gated policy (profiles, orders, order_items, wholesale_prices,
-- resources, tier_settings, order_settings, the dealer-resources
-- storage bucket, and the tier_pricing_reference view) inherits the
-- MFA requirement automatically, without touching each one individually.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  )
  and coalesce((auth.jwt() ->> 'aal'), '') = 'aal2';
$$;

-- ─── profiles ───
drop policy if exists "profiles: read own row" on public.profiles;
create policy "profiles: read own row"
  on public.profiles for select
  using (auth.uid() = id and public.has_mfa());

-- ─── wholesale_prices ───
drop policy if exists "wholesale_prices: approved users only" on public.wholesale_prices;
create policy "wholesale_prices: approved users only"
  on public.wholesale_prices for select
  using (
    public.has_mfa()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.approved = true)
  );

-- ─── resources ───
drop policy if exists "resources: approved users only" on public.resources;
create policy "resources: approved users only"
  on public.resources for select
  using (
    public.has_mfa()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.approved = true)
  );

-- ─── dealer-resources storage bucket ───
drop policy if exists "dealer-resources: approved users can read" on storage.objects;
create policy "dealer-resources: approved users can read"
  on storage.objects for select
  using (
    bucket_id = 'dealer-resources'
    and public.has_mfa()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.approved = true)
  );

-- ─── orders ───
drop policy if exists "orders: reseller insert own" on public.orders;
create policy "orders: reseller insert own"
  on public.orders for insert
  with check (
    public.has_mfa()
    and reseller_id = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.approved = true)
  );

drop policy if exists "orders: reseller select own" on public.orders;
create policy "orders: reseller select own"
  on public.orders for select
  using (reseller_id = auth.uid() and public.has_mfa());

-- ─── order_items ───
drop policy if exists "order_items: reseller insert own order" on public.order_items;
create policy "order_items: reseller insert own order"
  on public.order_items for insert
  with check (
    public.has_mfa()
    and exists (
      select 1 from public.orders o
      where o.id = order_items.order_id and o.reseller_id = auth.uid()
    )
  );

drop policy if exists "order_items: select if order visible" on public.order_items;
create policy "order_items: select if order visible"
  on public.order_items for select
  using (
    public.has_mfa()
    and exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and (o.reseller_id = auth.uid() or public.is_admin())
    )
  );

-- ─── tier_settings ───
drop policy if exists "tier_settings: authenticated read" on public.tier_settings;
create policy "tier_settings: authenticated read"
  on public.tier_settings for select
  using (auth.role() = 'authenticated' and public.has_mfa());

-- ─── order_settings ───
drop policy if exists "order_settings: authenticated read" on public.order_settings;
create policy "order_settings: authenticated read"
  on public.order_settings for select
  using (auth.role() = 'authenticated' and public.has_mfa());

-- Deliberately untouched: public_pricing (must stay readable by anon
-- visitors on the public product pages — they have no session/JWT at
-- all, so has_mfa() would always be false for them regardless).
