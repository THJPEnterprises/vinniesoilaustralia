-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Fix infinite recursion in admin RLS policies
-- Run in Supabase SQL Editor AFTER schema-orders.sql.
--
-- The "profiles: admin read all" policy checked admin status by querying
-- profiles again — but that query itself re-triggers RLS on profiles,
-- which re-runs the same policy, forever ("infinite recursion detected
-- in policy for relation 'profiles'"). The fix is a SECURITY DEFINER
-- helper function: it runs with elevated privileges internally, so its
-- own lookup bypasses RLS instead of re-triggering it.
-- ═══════════════════════════════════════════════════════════

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  );
$$;

-- ─── Replace the recursive profiles policies ───
drop policy if exists "profiles: admin read all" on public.profiles;
drop policy if exists "profiles: admin update all" on public.profiles;

create policy "profiles: admin read all"
  on public.profiles for select
  using (public.is_admin());

create policy "profiles: admin update all"
  on public.profiles for update
  using (public.is_admin());

-- ─── Update orders/order_items admin policies to use the same helper ───
-- (not strictly required to fix the recursion, but consistent and avoids
-- any similar issue in these policies going forward)
drop policy if exists "orders: admin select all" on public.orders;
drop policy if exists "orders: admin update all" on public.orders;

create policy "orders: admin select all"
  on public.orders for select
  using (public.is_admin());

create policy "orders: admin update all"
  on public.orders for update
  using (public.is_admin());

drop policy if exists "order_items: select if order visible" on public.order_items;

create policy "order_items: select if order visible"
  on public.order_items for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and (o.reseller_id = auth.uid() or public.is_admin())
    )
  );
