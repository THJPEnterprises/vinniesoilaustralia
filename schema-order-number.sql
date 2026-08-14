-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Sequential order numbers
-- Run in Supabase SQL Editor AFTER schema-orders.sql.
-- Adds an auto-generated VOA-00001, VOA-00002, ... number to every order,
-- alongside the reseller's own PO number (order_number is ours, po_number
-- is theirs — both are kept and shown together in the portal/admin UI).
-- ═══════════════════════════════════════════════════════════

create sequence if not exists public.order_number_seq start 1001;

create or replace function public.generate_order_number()
returns text as $$
begin
  return 'VOA-' || lpad(nextval('public.order_number_seq')::text, 5, '0');
end;
$$ language plpgsql;

alter table public.orders add column if not exists order_number text;
alter table public.orders alter column order_number set default public.generate_order_number();

-- Backfill any existing orders placed before this migration ran
update public.orders set order_number = public.generate_order_number() where order_number is null;

alter table public.orders alter column order_number set not null;
alter table public.orders add constraint orders_order_number_unique unique (order_number);

-- To change the starting number or prefix later:
--   alter sequence public.order_number_seq restart with 5000;
-- and edit the 'VOA-' literal / lpad width inside generate_order_number().
