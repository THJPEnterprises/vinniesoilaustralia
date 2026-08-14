-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Reseller Ordering System
-- Run in Supabase SQL Editor AFTER schema.sql and populate.sql.
-- ═══════════════════════════════════════════════════════════

-- ─── ORDERS ───
-- No payment processing here — this is Purchase Order / Payment on Account.
-- Shipping is intentionally left blank at submission time; admins fill it
-- in when they process the order (shown to resellers as "to be confirmed").
create table if not exists public.orders (
  id bigint generated always as identity primary key,
  reseller_id uuid not null references public.profiles(id) on delete cascade,
  po_number text not null,
  status text not null default 'submitted', -- submitted | confirmed | processing | shipped | cancelled
  subtotal_aud numeric(10,2) not null,
  gst_aud numeric(10,2) not null,
  shipping_aud numeric(10,2),              -- null until admin sets it
  notes text,                               -- reseller's own notes on the order
  admin_notes text,                         -- internal notes, not shown to reseller
  zoho_sales_order_id text,                 -- set once synced to Zoho Inventory
  zoho_sync_status text default 'not_synced', -- not_synced | syncing | synced | failed
  zoho_sync_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.orders enable row level security;

-- Resellers can insert orders for themselves, only if their profile is approved
create policy "orders: reseller insert own"
  on public.orders for insert
  with check (
    reseller_id = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.approved = true)
  );

-- Resellers can view their own orders
create policy "orders: reseller select own"
  on public.orders for select
  using (reseller_id = auth.uid());

-- Admins can view every order
create policy "orders: admin select all"
  on public.orders for select
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- Admins can update any order (status, shipping, notes, Zoho fields)
create policy "orders: admin update all"
  on public.orders for update
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- ─── ORDER ITEMS ───
create table if not exists public.order_items (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  sku text not null,
  product_name text not null,
  unit_price_aud numeric(10,2) not null,
  qty int not null check (qty > 0),
  line_total_aud numeric(10,2) not null
);

alter table public.order_items enable row level security;

-- Resellers can insert items into an order they just created themselves
create policy "order_items: reseller insert own order"
  on public.order_items for insert
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id and o.reseller_id = auth.uid()
    )
  );

-- Resellers can view items on their own orders; admins can view all
create policy "order_items: select if order visible"
  on public.order_items for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and (
          o.reseller_id = auth.uid()
          or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
        )
    )
  );

-- ─── ADMIN VISIBILITY INTO RESELLER PROFILES ───
-- The original schema.sql only let a user read their own profile row.
-- Admins need to see reseller/business details alongside their orders.
create policy "profiles: admin read all"
  on public.profiles for select
  using (
    exists (select 1 from public.profiles p2 where p2.id = auth.uid() and p2.role = 'admin')
  );

-- Admins can also update profiles (e.g. approve accounts from the admin UI
-- instead of only via Table Editor)
create policy "profiles: admin update all"
  on public.profiles for update
  using (
    exists (select 1 from public.profiles p2 where p2.id = auth.uid() and p2.role = 'admin')
  );

-- ─── MAKE YOURSELF AN ADMIN ───
-- Run this once, replacing the email, to grant admin access to the
-- pages/admin.html dashboard:
--
-- update public.profiles set role = 'admin', approved = true
-- where email = 'your-admin-email@example.com';
