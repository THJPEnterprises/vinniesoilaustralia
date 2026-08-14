-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Zoho Inventory sync support
-- Run in Supabase SQL Editor AFTER schema-orders.sql.
-- ═══════════════════════════════════════════════════════════

-- Each reseller needs to be linked to their matching Contact in Zoho
-- Inventory before their orders can sync (Zoho Sales Orders require a
-- customer_id). Set this manually per reseller once you've created/found
-- their Contact in Zoho:
--
-- update public.profiles set zoho_contact_id = '1234567890'
-- where email = 'reseller@example.com';
alter table public.profiles add column if not exists zoho_contact_id text;

-- Each product needs to be linked to its matching Item in Zoho Inventory
-- before it can appear on a synced Sales Order. Set this manually per
-- product once you've found its Item ID in Zoho:
--
-- update public.wholesale_prices set zoho_item_id = '9876543210'
-- where sku = 'VO-UPO-270';
alter table public.wholesale_prices add column if not exists zoho_item_id text;

-- Admins need to edit these two fields from Table Editor (no dedicated UI
-- for this yet) — see PORTAL-SETUP.md for the full Zoho setup walkthrough.
