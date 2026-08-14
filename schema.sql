-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Reseller/Wholesaler Portal
-- Supabase schema: run this in Supabase SQL Editor
-- (Project → SQL Editor → New query → paste → Run)
-- ═══════════════════════════════════════════════════════════

-- ─── PROFILES ───
-- One row per portal user, linked to Supabase Auth. Created automatically
-- when a user is invited/signs in. "approved" gates access — set true
-- manually (or via your own approval flow) before a reseller can see data.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  business_name text,
  approved boolean not null default false,
  role text not null default 'reseller', -- 'reseller' | 'wholesaler' | 'admin'
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Users can read their own profile row (so the portal can check "approved")
create policy "profiles: read own row"
  on public.profiles for select
  using (auth.uid() = id);

-- Auto-create a profile row whenever a new auth user is created
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─── WHOLESALE PRICING ───
create table if not exists public.wholesale_prices (
  id bigint generated always as identity primary key,
  sku text not null,
  product_name text not null,
  size text,
  wholesale_price_aud numeric(10,2) not null,
  rrp_aud numeric(10,2),
  min_order_qty int default 1,
  notes text,
  updated_at timestamptz not null default now()
);

alter table public.wholesale_prices enable row level security;

-- Only approved, logged-in users can view pricing
create policy "wholesale_prices: approved users only"
  on public.wholesale_prices for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.approved = true
    )
  );

-- ─── DEALER RESOURCES (metadata; files live in Storage) ───
create table if not exists public.resources (
  id bigint generated always as identity primary key,
  title text not null,
  description text,
  file_path text not null, -- path inside the 'dealer-resources' storage bucket
  category text default 'general', -- 'pricing' | 'marketing' | 'spec-sheet' | 'sds' | 'general'
  updated_at timestamptz not null default now()
);

alter table public.resources enable row level security;

create policy "resources: approved users only"
  on public.resources for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.approved = true
    )
  );

-- ─── STORAGE BUCKET FOR DEALER FILES ───
-- Run once: creates a private bucket. Upload files via Supabase Studio
-- (Storage → dealer-resources) and reference their path in `resources.file_path`.
insert into storage.buckets (id, name, public)
values ('dealer-resources', 'dealer-resources', false)
on conflict (id) do nothing;

create policy "dealer-resources: approved users can read"
  on storage.objects for select
  using (
    bucket_id = 'dealer-resources'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.approved = true
    )
  );

-- ─── EXAMPLE DATA (delete or edit as needed) ───
-- insert into public.wholesale_prices (sku, product_name, size, wholesale_price_aud, rrp_aud, min_order_qty)
-- values ('VO-UPO-1L', 'Ultra Penetrating Oil', '1L', 42.00, 69.95, 6);
