# Reseller & Wholesaler Portal — Setup Guide

This adds a secured login portal (`pages/portal-login.html` → `pages/portal.html`) for resellers/wholesalers, backed by **Supabase** (auth + database) and served from **Cloudflare Pages**.

## 1. Create the Supabase project

1. Go to [supabase.com](https://supabase.com) → New Project (free tier is fine).
2. Once created, go to **Project Settings → API** and copy:
   - **Project URL**
   - **anon public** key
3. Open `js/portal-config.js` in the site and paste them in:
   ```js
   window.SUPABASE_URL = 'https://your-project-ref.supabase.co';
   window.SUPABASE_ANON_KEY = 'your-anon-public-key';
   ```
   The anon key is safe to expose in the browser — it only grants what the Row Level Security (RLS) policies below allow.

## 2. Run the database schema

1. In Supabase: **SQL Editor → New query**.
2. Paste the contents of `schema.sql` (included alongside this guide) and click **Run**.

This creates:
- `profiles` — one row per portal user, with an `approved` flag that gates access.
- `wholesale_prices` — your wholesale price list.
- `resources` — dealer resource metadata (spec sheets, marketing assets).
- A private `dealer-resources` storage bucket for the actual files.
- RLS policies so only **signed-in, approved** users can read pricing/resources.

## 2b. Load starter pricing & resources from the current site

1. In Supabase: **SQL Editor → New query**, paste the contents of `populate.sql`, click **Run**.
2. This adds every product currently listed on the website (UPO, Rustic Dark, Eternal Seal, Monocoat, Hard Wax, Soft Wax, the 3 bundles, and apparel) into `wholesale_prices` with the wholesale price left at `$0.00` — edit those in **Table Editor → wholesale_prices** since actual wholesale pricing isn't published on the public site.
3. It also adds rows to `resources` for the 6 SDS sheets, the application/maintenance guides, the marketing/POS kit and the training deck mentioned on the Resources page — but the `file_path` values are placeholders. Upload the real files to **Storage → dealer-resources** first, then edit each row's `file_path` in **Table Editor → resources** to match the uploaded file exactly (e.g. `sds/upo-sds.pdf`). Rows with a placeholder path will show a broken download link until updated.

## 3. Add reseller accounts

Supabase doesn't have public self-signup enabled by this setup on purpose — you control who gets access (wholesale-only, matches your current "apply to become a stockist" model).

1. **Authentication → Users → Add user** (invite by email, or set a temporary password).
2. In **Table Editor → profiles**, find the new user's row and set `approved = true`. Optionally fill in `business_name`.
3. The user can now sign in at `/pages/portal-login.html`. If you didn't set a password, they can use "Reset it here" on the login page to set one via email.

To reject/pause an account, set `approved = false` — they stay logged in but the portal shows "Access Pending Approval" and won't load pricing/resources.

## 4. Add pricing and resources

- **Pricing:** Table Editor → `wholesale_prices` → insert rows (SKU, product name, size, wholesale price, RRP, min order qty).
- **Resources (documents):** Storage → `dealer-resources` bucket → upload files (PDFs, spec sheets). Then Table Editor → `resources` → add a row with `file_path` matching the uploaded file's path, plus a title/description. Use `category` of `sds`, `spec-sheet`, `marketing` or `general` — these show up in the "Dealer Resources" list on the portal.

### Product image gallery

The portal has a dedicated **Product Image Gallery** section, separate from the document list, with real thumbnails.

1. Upload images to Storage → `dealer-resources`, e.g. in a `product-images/` folder.
2. In Table Editor → `resources`, add a row per image with `category = 'product-images'` exactly (this is what routes it into the gallery instead of the document list). `file_path` should match the uploaded image path, e.g. `product-images/upo-hero.jpg`.
3. Images appear as clickable thumbnails on the portal with "View full size" and "Download" links, using the same 1-hour signed URLs as documents.

## 5. Deploy to Cloudflare Pages

Since Supabase needs the site served over HTTPS with a real origin (not `file://`), and to keep everything on one modern free host:

1. Push this site to a GitHub repository (or connect the existing one).
2. In [Cloudflare Pages](https://dash.cloudflare.com) → **Create a project → Connect to Git**.
3. Framework preset: **None** (static site). Build command: none. Output directory: `/` (root).
4. Deploy. Cloudflare gives you a `*.pages.dev` URL immediately; add your custom domain under **Custom domains** the same way you would have with GitHub Pages.
5. In Supabase → **Authentication → URL Configuration**, add your live site URL (and the `.pages.dev` preview URL) to **Redirect URLs** — needed for the password reset link to work.

## 5b. Set up Resend for auth emails (password reset, invites)

Supabase's built-in email sender is rate-limited and only meant for testing — for real reseller accounts, connect Resend as custom SMTP so reset/invite emails actually deliver reliably.

1. In [Resend](https://resend.com), add and verify your sending domain (e.g. `vinniesoilaustralia.com`) under **Domains** — this means adding the DNS records Resend gives you (SPF/DKIM) wherever your domain's DNS is managed (Cloudflare, since that's already in the picture). Verification can take a few minutes to a few hours depending on DNS propagation.
2. Create an API key under **API Keys** (full access, or restrict to "Sending" if offered).
3. In Supabase → **Authentication → Settings → SMTP Settings**, enable custom SMTP and enter:
   - **Sender email:** an address on your verified domain, e.g. `noreply@vinniesoilaustralia.com`
   - **Sender name:** `Vinnie's Oil Australia`
   - **Host:** `smtp.resend.com`
   - **Port:** `465`
   - **Username:** `resend`
   - **Password:** your Resend API key
4. Save, then test by triggering "Reset it here" on the login page for a real account — it should arrive within a minute or two.

Until the domain is verified in Resend, sending will fail or emails may land in spam — verify the domain first before relying on this for real invites.

## 7. Reseller ordering system (Purchase Order / Payment on Account)

Adds `pages/portal-order.html` (place an order), `pages/portal-orders.html` (order history), and `pages/admin.html` (admin dashboard). No payment is processed — this is PO/Payment on Account only.

1. Run `schema-orders.sql` in SQL Editor (after `schema.sql`/`populate.sql`). Creates `orders` and `order_items` tables, RLS so resellers only see their own orders and admins see everything, and lets admins update `profiles` too (needed for the approvals tab).
2. **Make yourself an admin** — run in SQL Editor:
   ```sql
   update public.profiles set role = 'admin', approved = true
   where email = 'your-admin-email@example.com';
   ```
3. Visit `/pages/admin.html` while signed in as that account — you'll see three tabs: **Orders** (every reseller's orders, click one to view line items and set status/shipping/internal notes), **Products & Pricing**, and **Resellers** (see section 9 below for both).

How it works for resellers: `portal-order.html` pulls live pricing from `wholesale_prices`, enforces each product's `min_order_qty`, calculates subtotal + 10% GST client-side, and shows shipping as "to be confirmed" (per your instruction — no shipping calculator, admin quotes it after submission). On submit it writes to `orders` + `order_items`. `portal-orders.html` shows the reseller their own order history and status.

## 8. Zoho Inventory sync (optional, admin-triggered)

The admin order detail view has a **"Sync to Zoho Inventory"** button that creates a matching Sales Order in Zoho via their API. This requires additional one-time setup — it won't work until you complete it.

### 8a. Get Zoho API credentials

1. Go to the [Zoho API Console](https://api-console.zoho.com) → **Add Client** → **Self Client** (simplest option for server-to-server use, no redirect URL needed).
2. Note the **Client ID** and **Client Secret** it gives you.
3. Under the **Generate Code** tab for that client, enter scope `ZohoInventory.salesorders.CREATE,ZohoInventory.contacts.READ,ZohoInventory.items.READ`, generate a code, and exchange it for a refresh token (Zoho's console walks you through this — the code is short-lived, the refresh token it produces is what you actually need and doesn't expire).
4. Find your **Organization ID**: Zoho Inventory → Settings → Organization Profile.
5. Note your **data center domain** — Australian accounts are typically `accounts.zoho.com.au` (accounts) and `www.zohoapis.com.au` (API), but check what your Zoho account actually uses (visible in the URL when logged into Zoho Inventory).

### 8b. Deploy the Edge Function

The function code lives in `supabase/functions/zoho-sync-order/index.ts`. You'll need the [Supabase CLI](https://supabase.com/docs/guides/cli) installed locally:

```bash
supabase login
supabase link --project-ref your-project-ref
supabase functions deploy zoho-sync-order

supabase secrets set ZOHO_CLIENT_ID=your_client_id
supabase secrets set ZOHO_CLIENT_SECRET=your_client_secret
supabase secrets set ZOHO_REFRESH_TOKEN=your_refresh_token
supabase secrets set ZOHO_ORGANIZATION_ID=your_org_id
supabase secrets set ZOHO_ACCOUNTS_DOMAIN=accounts.zoho.com.au
supabase secrets set ZOHO_API_DOMAIN=www.zohoapis.com.au
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

The service role key is in Supabase → Project Settings → API — this is the one that must stay private, which is why it's only ever set as a server-side secret, never in any client-facing file in this repo.

### 8c. Link resellers and products to Zoho

Run `schema-zoho.sql` in SQL Editor first (adds two columns). Then, before syncing will work for a given order, link each reseller and product to its matching Zoho record:

- **Per reseller:** Admin → Resellers tab → **Zoho Contact ID** column. Find the Contact ID in Zoho Inventory → Contacts.
- **Per product:** Admin → Products & Pricing tab → **Zoho Item ID** column. Find the Item ID in Zoho Inventory → Items.

No SQL needed for either — edit the field and click Save, same as any other row. (You can still set these directly in Table Editor if you prefer: `update public.profiles set zoho_contact_id = '...' where email = '...';` / `update public.wholesale_prices set zoho_item_id = '...' where sku = '...';`)

If either is missing when an admin clicks "Sync to Zoho," the function fails with a clear message telling you exactly what's missing rather than partially syncing.

## 9. Admin: pricing management, reseller accounts, and public RRP sync

Run `schema-admin-extras.sql` in SQL Editor (after `schema-fix-rls-recursion.sql`). This adds admin write access to pricing and a public-safe view for RRP.

### Products & Pricing tab

Full CRUD on `wholesale_prices` directly from `/pages/admin.html` — no more Table Editor needed for day-to-day price changes. Click **+ Add Product** for a new row, edit any field inline, **Save** per row, or **Delete**. Changes take effect immediately on the reseller portal's price list and order form.

**This also drives the public website's Recommended Retail Price.** The 6 product pages (`product-upo.html` and friends) now pull their RRP live from Supabase via a `public_pricing` view — a version of `wholesale_prices` with only `sku`, `product_name`, `size`, `rrp_aud` exposed publicly (wholesale cost stays private, never exposed to anonymous visitors). Editing a product's RRP in the admin tab updates the live site within moments — no code deploy needed. If Supabase is ever unreachable when a visitor loads the page, the originally hardcoded price silently stays shown instead of breaking anything.

### Resellers tab

Shows every reseller account (not just pending ones) in one table — edit business name, change role (reseller/wholesaler/admin), toggle approved, all inline with a **Save** button per row. The badge on the tab shows how many are still awaiting approval.

**+ Create New User** opens a form to create a brand new account directly — email, business name, a temporary password you set, role, and whether to approve it immediately. This requires the `admin-create-user` Edge Function to be deployed (same deployment pattern as the Zoho function):

```bash
supabase functions deploy admin-create-user
```

It reuses the same `SUPABASE_SERVICE_ROLE_KEY` secret you'd have already set for Zoho — if you haven't set up Zoho yet, set it now:

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

Creating a user this way sets `email_confirm: true` (skips email verification, since the admin is vouching for the account directly) and creates the account with the temp password ready to use immediately — tell the reseller the password separately, and they can change it via "Reset it here" on the login page whenever they like.

## 10. Overall order minimum (replaces per-product MOQ)

Run `schema-order-minimum.sql` in SQL Editor (after `schema-admin-extras.sql`). This adds an `order_settings` table with a single number: the minimum total quantity across an *entire* order, any mix of products — replacing the old behaviour where each product's own minimum blocked small quantities individually (e.g. 2 of one item + 3 of another used to fail even though the combined total was reasonable).

- Resellers see a running "Order total: X units / Minimum order: Y units" banner on the order form, and Submit stays disabled until the total is met.
- Admins can change the minimum any time from the **Products & Pricing** tab in `/pages/admin.html` — no SQL needed after the initial migration.
- Default is 10 units; change it via the admin UI or directly:
  ```sql
  update public.order_settings set min_order_qty = 10 where id = 1;
  ```

## 11. Reseller tiers

Adds three wholesale tiers, each with its own margin, order minimum, and shipping benefit — replacing the old "one price for everyone" model. A product's price to a given reseller is now calculated automatically as **RRP × (1 − their tier's margin %)**, rather than a single flat wholesale price.

1. Run `schema-reseller-tiers.sql` in SQL Editor (after `schema-order-minimum.sql`). Creates `tier_settings` (3 seeded rows: Tier 1 = 35% margin / 10 unit minimum, Tier 2 = 40% / 25 units, Tier 3 = 50% / 50 units + free shipping), adds a `tier` column to `profiles` (defaults everyone to Tier 1), and a `reseller_tier` column on `orders` so you can see which tier pricing an order was placed under.
2. **Admin → Reseller Tiers tab**: edit each tier's label, margin %, order minimum, free-shipping toggle, and the benefits text shown to resellers — no SQL needed for day-to-day changes.
3. **Admin → Resellers tab**: assign each reseller to Tier 1/2/3 with the new Tier dropdown, alongside role and approval. There's no automatic tier upgrade — set this manually based on a reseller's typical order volume.
4. Resellers see their current tier on the Dashboard (badge + link to a full tier comparison), the order form (tier pricing applied automatically, order minimum enforced per their tier, free shipping shown if their tier includes it), and a dedicated `pages/portal-tiers.html` page explaining all three tiers with their own highlighted.
5. The old single "Overall Order Minimum" setting (`order_settings` table, section 10 above) is superseded by each tier's own minimum — you can leave `order_settings` in place, it's just no longer read by the order form.

## 12. Reseller state & region coverage

Adds a State (dropdown of NSW/VIC/QLD/SA/WA/TAS/NT/ACT) and a free-text Region field to each reseller's account, so you can see and manage which part of the country a reseller covers.

1. Run `schema-reseller-region.sql` in SQL Editor (after `schema-reseller-tiers.sql`). Adds `state` and `region` columns to `profiles`.
2. Redeploy the `admin-create-user` Edge Function (it now accepts and saves state/region on account creation):
   ```bash
   supabase functions deploy admin-create-user
   ```
3. **Admin → Resellers tab**: State and Region columns are now editable inline for every existing reseller, alongside role/tier/approval.
4. **Admin → Resellers → + Create New User**: set State and Region when creating a brand-new account.
5. A reseller's state/region (if set) now shows in the Orders tab order detail view, next to their business name — handy context when confirming shipping.

This is admin-managed data only — resellers don't see or edit their own state/region in the portal.

## 13. Supabase Advisor cleanup (function search_path, leaked password protection)

Run `schema-fix-function-search-path.sql` any time in SQL Editor — pins `search_path` on `handle_new_user()` and `generate_order_number()` so Supabase's Advisor stops flagging "Function Search Path Mutable" on them. No behaviour change, just closes a theoretical search_path-hijacking gap on two functions that run with elevated privileges.

Also enable **Leaked Password Protection**: Supabase dashboard → Authentication → Settings → Password, turn on "Leaked password protection" — checks new passwords against known breached-password lists at signup/reset, no code change needed.

The "Security Definer View" warning on `public_pricing` and the various "Auth RLS Initialization Plan" / "Multiple Permissive Policies" notices are expected/low-priority — see the note in section 9 about `public_pricing` being intentional, and the RLS ones are performance suggestions only relevant at much higher traffic than this site sees.

## 14. Admin-managed Dealer Resources

Adds a **Dealer Resources** tab to `/pages/admin.html` so SDS sheets, application/maintenance guides, the marketing kit, and the product image gallery can all be managed without touching Table Editor or Storage directly.

1. Run `schema-admin-resources.sql` in SQL Editor (after `schema-admin-extras.sql`) — grants admins insert/update/delete on the `resources` table and the `dealer-resources` Storage bucket (previously read-only for admins too, same as everyone else).
2. **Admin → Dealer Resources tab**: edit title, description and category inline, and either upload a file directly (drag/select a file, it uploads to Storage automatically on Save) or paste an external URL (e.g. a Google Drive share link) into the file field instead — same dual-mode support the portal already had for reading resources.
3. Category `product-images` routes an entry into the reseller Dashboard's image gallery; any other category (`sds`, `spec-sheet`, `marketing`, `general`) shows in the Dealer Resources list instead.
4. **+ Add Resource** creates a blank row — fill in the details and upload a file or paste a link, then Save.
5. Deleting a resource removes the portal listing but does not delete the underlying file from Storage — clean up unused files from Storage → dealer-resources separately if needed.

## 15. Admin-only tier pricing reference view

The `wholesale_prices` table only ever stores one flat `wholesale_price_aud` figure (a legacy reference column) — actual Tier 1/2/3 prices are computed live in the browser from RRP × each tier's margin %, and never written back to the database. That's expected, but it means you can't just glance at Table Editor and see all 3 tiers' prices per product.

Run `schema-admin-tier-pricing-view.sql` in SQL Editor (after `schema-reseller-tiers.sql`) to add a `tier_pricing_reference` view in Table Editor showing SKU, product name, RRP, and each tier's margin % + computed price side by side — for your own reference only.

This view is restricted to admin accounts: non-admin authenticated users get zero rows back even though the grant technically allows SELECT, and there's no access at all for anon/public. It's the deliberate opposite of the `public_pricing` view (that one is intentionally public-safe; this one is not).

## 16. Sized products (T-shirts / apparel)

Lets a product (like a T-shirt) be ordered with a size breakdown — a reseller can order, say, 5 Medium and 3 Large in the same order, and each size shows up as its own line for you and in Zoho.

1. Run `schema-product-sizes.sql` in SQL Editor (after `schema-orders.sql`). Adds `has_sizes` and `available_sizes` to `wholesale_prices`, and a `size` column to `order_items`. Doesn't touch existing liquid products — `has_sizes` defaults to false and they order exactly as before.
2. **Admin → Products & Pricing tab**: tick "Has Sizes?" for a product (e.g. your T-shirt SKU) and enter its sizes comma-separated in the new "Sizes" field, e.g. `S,M,L,XL,XXL`.
3. On the reseller order form, a sized product automatically expands into one row per size (e.g. "Vinnie's Oil T-Shirt — Size M") — the reseller enters a quantity for each size they want, same as any other product, and the overall order minimum still counts every unit across every size and product.
4. Order confirmations, "My Orders", and the admin Orders tab all show the size next to the product name on each line. If you sync an order to Zoho, the size is included in the line item name/description too.

## 17. Mandatory two-factor authentication (MFA)

Every account — reseller and admin — must set up two-factor authentication via an authenticator app (Google Authenticator, Authy, 1Password, etc.) before they can use the portal. This uses Supabase Auth's built-in TOTP support, so there's no extra service, no per-user cost, and no SMS fees.

1. Run `schema-mfa-enforcement.sql` in SQL Editor (after `schema-admin-resources.sql`). This is the part that actually matters for security: it adds a `has_mfa()` check into the RLS policies on every table (profiles, orders, order_items, wholesale_prices, resources, tier_settings, order_settings, the dealer-resources storage bucket) so data simply cannot be read or written without a completed MFA challenge this session — enforced at the database level, not just hidden by the page. `public_pricing` is deliberately left untouched since anonymous website visitors need to keep seeing RRP with no login at all.
2. **First sign-in for any account**: after entering email/password, they're shown a QR code to scan with their authenticator app, then enter the 6-digit code it generates to confirm setup. From then on, every sign-in asks for a fresh 6-digit code after the password.
3. Deploy the new `admin-reset-mfa` Edge Function (same pattern as the others):
   ```bash
   supabase functions deploy admin-reset-mfa
   ```
   It reuses the same `SUPABASE_SERVICE_ROLE_KEY` secret already set for the other admin functions.
4. **Lost device recovery**: if someone loses their phone/authenticator app, they can't get back in on their own (by design — that's the whole point of mandatory MFA). **Admin → Resellers tab** now has a **Reset MFA** button per account — clicking it clears their enrolled factor, and they're taken through the QR setup again from scratch on their next sign-in.

## 18. Tier 3 renamed to Gold (45%), new Tier 4 Platinum (50%)

Run `schema-tier-gold-platinum.sql` in SQL Editor (after `schema-reseller-tiers.sql`). Renames Tier 3 to "Gold" and drops its margin from 50% to 45%, and adds a new Tier 4 "Platinum" at 50% margin with a 100-unit per-order minimum.

Platinum's real qualifying bar — a quarterly order volume of 50+ units — isn't something the system tracks automatically (tiers are still assigned manually in Admin → Resellers, same as every other tier), so it's spelled out in the tier's benefits text shown to resellers on the "Your Tier" comparison page rather than being a live gate on the order form. Review it manually each quarter when deciding who stays at Platinum.

Platinum's extra perks (30-day account terms, priority dispatch, early access to new/limited product lines, a 2% quarterly volume rebate on paid orders, marketing posters/displays, and being featured as a "Preferred Partner") are listed on the tier comparison page — these are benefits you deliver manually (invoicing terms, dispatch priority, rebate payment, etc.), the portal doesn't automate any of them.

**"Preferred Partner" badge**: originally added as a one-off static edit to Arborean's card on `pages/retail-network.html`. This has since been replaced by full admin-managed retailer listings — see section 19 below.

## 19. Admin-managed Retail Network listings

Run `schema-retailers.sql` in SQL Editor. Creates a `retailers` table (business name, state, description, website, `preferred_partner` flag, `active` flag, `sort_order`) with RLS: anyone can read `active = true` rows, only admins can read/write everything else. Seeds it with the existing Arborean (NSW) listing, `preferred_partner = true`.

Manage retailers in Admin → Retail Network: add/edit/delete listings, toggle Preferred Partner (shows the gold "★ Preferred Partner" badge on their public card) and Active (unticking Active hides a retailer from the public page without deleting their record — use this instead of Delete when a stockist relationship pauses).

`pages/retail-network.html` now fetches active retailers live from Supabase and renders their cards into the existing state-filtered grid — no more hardcoded stockist HTML. The "Coming Soon" per-state placeholders and the "Online Retail Partners" card are still static and untouched.

## 6. Security notes

- Wholesale pricing and files are only ever fetched **after** Supabase confirms the session and `approved = true` — they're not sitting in the page source like a client-side password gate would be.
- Downloadable resources use **signed URLs** (expire after 1 hour), so links can't be shared indefinitely.
- Rotate the anon key only if you regenerate it in Supabase; it does not need to be secret, but do keep your **service role key** (a different key, not used anywhere in this site) out of any client code — it's never referenced here.
