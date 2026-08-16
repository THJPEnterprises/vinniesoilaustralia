-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Per-product apparel sizing (T-shirts etc.)
-- Run in Supabase SQL Editor AFTER schema-orders.sql.
--
-- Some products (T-shirts) need a size breakdown at order time — a
-- reseller might want 5 Medium and 3 Large in one order. This adds an
-- opt-in "has sizes" flag + size list to a product, and a size column
-- on order_items so each size a reseller orders becomes its own line
-- with its own quantity, all still against the same product/SKU.
--
-- Doesn't affect existing liquid products at all — has_sizes defaults
-- to false and the order form behaves exactly as before for them.
-- ═══════════════════════════════════════════════════════════

alter table public.wholesale_prices
  add column if not exists has_sizes boolean not null default false,
  add column if not exists available_sizes text; -- comma-separated, e.g. 'S,M,L,XL,XXL'

alter table public.order_items
  add column if not exists size text; -- garment size for this line; null for non-sized products

-- Example: mark a T-shirt product as sized (run after adding it in the
-- admin Products & Pricing tab, or via SQL):
-- update public.wholesale_prices set has_sizes = true, available_sizes = 'S,M,L,XL,XXL' where sku = 'VO-TSHIRT';
