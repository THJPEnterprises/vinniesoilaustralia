-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Admin-managed Retail Network listings
-- Run in Supabase SQL Editor AFTER schema-tier-gold-platinum.sql.
--
-- Moves the retailer cards on pages/retail-network.html (currently
-- hardcoded HTML) into the database, managed from a new Admin →
-- Retail Network tab — including a Preferred Partner toggle, which is
-- what this was built for. The "Coming Soon" placeholder cards per
-- state and the generic "Online Retail Partners" card stay as static
-- HTML on the page itself, since they're not real accounts.
-- ═══════════════════════════════════════════════════════════

create table if not exists public.retailers (
  id bigint generated always as identity primary key,
  business_name text not null,
  state text not null,       -- 'nsw' | 'vic' | 'qld' | 'wa' | 'sa' | 'act' | 'nt' | 'online'
  description text,
  website_url text,
  preferred_partner boolean not null default false,
  active boolean not null default true,  -- unpublish without deleting
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.retailers enable row level security;

-- Public (including anonymous website visitors) can read active listings —
-- this is the same public marketing page anyone can already see with no
-- login, just now database-driven instead of hardcoded HTML.
create policy "retailers: public read active"
  on public.retailers for select
  using (active = true);

-- Admins can see everything (including inactive) and manage listings.
create policy "retailers: admin read all"
  on public.retailers for select
  using (public.is_admin());

create policy "retailers: admin insert"
  on public.retailers for insert
  with check (public.is_admin());

create policy "retailers: admin update"
  on public.retailers for update
  using (public.is_admin());

create policy "retailers: admin delete"
  on public.retailers for delete
  using (public.is_admin());

-- Carry over Arborean, the one real retailer currently hardcoded on the
-- page, as a Preferred Partner (matches the badge already live).
insert into public.retailers (business_name, state, description, website_url, preferred_partner, sort_order)
values (
  'Arborean',
  'nsw',
  'Specialist woodworking and timber products retailer. Full range of Vinnie''s Oil products and expert application advice.',
  'http://arborean.com.au',
  true,
  0
);
