-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Reseller state & region coverage
-- Run in Supabase SQL Editor AFTER schema-reseller-tiers.sql.
--
-- Adds a state (dropdown of AU states/territories) and a free-text
-- region field to each reseller's profile, so admins can see/filter
-- which part of the country a reseller covers. Set from the admin
-- Create New User form or edited inline on the Resellers tab —
-- resellers themselves don't edit this.
-- ═══════════════════════════════════════════════════════════

alter table public.profiles
  add column if not exists state text,   -- 'NSW' | 'VIC' | 'QLD' | 'SA' | 'WA' | 'TAS' | 'NT' | 'ACT'
  add column if not exists region text;  -- free text, e.g. "Greater Brisbane", "Far North Queensland"

-- (Existing "profiles: admin update all" policy already covers updating
-- these new columns — no new RLS policy needed.)

-- To set a reseller's state/region later without the admin UI:
-- update public.profiles set state = 'QLD', region = 'Greater Brisbane' where email = 'reseller@example.com';
