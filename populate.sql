-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Portal starter data
-- Pulled from the current website's product & resources pages.
-- Run in Supabase SQL Editor AFTER schema.sql.
-- Wholesale prices below are PLACEHOLDERS ($0.00) — edit them
-- directly in Table Editor → wholesale_prices once run.
-- ═══════════════════════════════════════════════════════════

-- ─── WHOLESALE PRICE LIST (products currently on the site) ───
insert into public.wholesale_prices (sku, product_name, size, wholesale_price_aud, rrp_aud, min_order_qty, notes) values
('VO-UPO-270',        'Ultra Penetrating Oil (UPO)',        '270ml', 0.00, null, 1, 'Flagship product — 2K system base coat'),
('VO-UPO-RUSTIC-270', 'UPO – Rustic Dark',                  '270ml', 0.00, null, 1, 'Dark-toned penetrating oil'),
('VO-ETERNAL-270',    'Eternal Seal',                       '270ml', 0.00, null, 1, '2K system topcoat / seal'),
('VO-MONOCOAT-270',   'Universal Monocoat (UNI)',           '270ml', 0.00, null, 1, 'All-in-one, one-coat hardwax oil'),
('VO-HARDWAX-270',    'Vinnie''s Hard Wax',                 '270ml', 0.00, null, 1, 'Most concentrated hard wax, buffed finish'),
('VO-SOFTWAX',        'Vinnie''s Soft Wax',                 null,    0.00, null, 1, 'Maintenance / easy-application wax'),
('VO-BUNDLE-UPOSEAL', 'Bundle — UPO + Eternal Seal',        '2x270ml', 0.00, null, 1, 'Premium 2K natural system'),
('VO-BUNDLE-UPOHARD', 'Bundle — UPO + Hard Wax',            '2x270ml', 0.00, null, 1, 'Classic 2K combo — food safe, high traffic'),
('VO-BUNDLE-BASE',    'Oil Base Series (Starter Bundle)',   'multi', 0.00, null, 1, 'Entry-point curated bundle'),
('VO-APPAREL-TEE',    'Vinnie''s Oil T-Shirt',              null,    0.00, null, 1, 'Branded apparel'),
('VO-APPAREL-CAP',    'Vinnie''s Oil Baseball Cap',         null,    0.00, null, 1, 'Branded apparel');

-- ─── DEALER RESOURCES (metadata only) ───
-- file_path accepts TWO formats — the portal now handles both:
--   1. A path inside the dealer-resources Storage bucket, e.g. 'sds/upo-sds.pdf'
--      → portal generates a 1-hour signed URL (gated behind login).
--   2. A full external link (e.g. a Google Drive share URL, https://drive.google.com/...)
--      → portal links straight to it, no Storage upload needed.
--      NOTE: if the Drive link is set to "Anyone with the link can view", it
--      is NOT actually gated by the portal login — anyone with the URL can
--      open it even if they never sign in. Keep Drive sharing set to
--      "Restricted" if you want these to stay reseller-only, or move the
--      file into Storage instead for real access control.
--
-- The SDS rows below are PLACEHOLDER Storage paths — since your SDS
-- documents currently live on Google Drive, replace each file_path with the
-- real Drive share link instead (Table Editor → resources → file_path).
insert into public.resources (title, description, file_path, category) values
('Ultra Penetrating Oil (UPO) — SDS',    'Safety Data Sheet for UPO 270ml.',                                   'sds/upo-sds.pdf',              'sds'),
('UPO – Rustic Dark — SDS',              'Safety Data Sheet for UPO Rustic Dark 270ml.',                       'sds/upo-rustic-sds.pdf',       'sds'),
('Eternal Seal — SDS',                   'Safety Data Sheet for Eternal Seal 270ml.',                          'sds/eternal-seal-sds.pdf',     'sds'),
('Universal Monocoat (UNI) — SDS',       'Safety Data Sheet for Universal Monocoat 270ml.',                    'sds/monocoat-sds.pdf',         'sds'),
('Hard Wax — SDS',                       'Safety Data Sheet for Hard Wax 270ml.',                              'sds/hard-wax-sds.pdf',         'sds'),
('Soft Wax — SDS',                       'Safety Data Sheet for Soft Wax.',                                    'sds/soft-wax-sds.pdf',         'sds'),
('Application Instructions — 2K System', 'Step-by-step guide: UPO + Hard Wax / Eternal Seal application.',    'guides/2k-system-guide.pdf',   'spec-sheet'),
('Application Instructions — Monocoat',  'Step-by-step guide: Universal Monocoat one-coat application.',      'guides/monocoat-guide.pdf',    'spec-sheet'),
('Maintenance & Re-coating Guide',       'Guide for maintenance waxing and spot repairs.',                    'guides/maintenance-guide.pdf', 'spec-sheet'),
('System Comparison Chart',              'Feature comparison across the full Vinnie''s Oil range.',           'guides/system-comparison.pdf', 'spec-sheet'),
('Dealer Marketing & POS Kit',           'Branded point-of-sale materials, product cards and display assets.','marketing/pos-kit.zip',        'marketing'),
('Product Training Deck',                'Staff training presentation — philosophy, range, application.',     'marketing/training-deck.pdf',  'marketing');

-- ─── PRODUCT IMAGE GALLERY (metadata only) ───
-- The current website's product photos are hosted externally (Google Sites
-- CDN) — they aren't local files, so they can't be auto-uploaded to Supabase
-- Storage from here. Download the images you want resellers to have
-- (right-click → save from the live site, or use your original source
-- files), upload them to Storage → dealer-resources → product-images/,
-- then update file_path below to match. category = 'product-images' is
-- what routes these into the portal's gallery instead of the document list.
insert into public.resources (title, description, file_path, category) values
('Ultra Penetrating Oil (UPO) — Product Shot',  'Hero product photography, 270ml can.',        'product-images/upo-hero.jpg',            'product-images'),
('UPO – Rustic Dark — Product Shot',            'Hero product photography, 270ml can.',        'product-images/upo-rustic-hero.jpg',     'product-images'),
('Eternal Seal — Product Shot',                 'Hero product photography, 270ml can.',        'product-images/eternal-seal-hero.jpg',   'product-images'),
('Universal Monocoat — Product Shot',           'Hero product photography, 270ml can.',        'product-images/monocoat-hero.jpg',       'product-images'),
('Hard Wax — Product Shot',                     'Hero product photography, 270ml can.',        'product-images/hard-wax-hero.jpg',       'product-images'),
('Soft Wax — Product Shot',                     'Hero product photography.',                   'product-images/soft-wax-hero.jpg',       'product-images');
