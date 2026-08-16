-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Pin search_path on SECURITY DEFINER functions
-- Run any time in Supabase SQL Editor — safe to run alongside existing data.
--
-- Supabase's Advisor flags "Function Search Path Mutable" on functions
-- that don't explicitly pin their search_path. Both of these run with
-- elevated privileges (handle_new_user is SECURITY DEFINER), so without a
-- pinned search_path there's a theoretical risk of search_path hijacking.
-- Pinning it to 'public, pg_temp' closes that off with no behaviour change.
-- ═══════════════════════════════════════════════════════════

alter function public.handle_new_user() set search_path = public, pg_temp;
alter function public.generate_order_number() set search_path = public, pg_temp;
