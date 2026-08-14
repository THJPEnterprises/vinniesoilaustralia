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

## 6. Security notes

- Wholesale pricing and files are only ever fetched **after** Supabase confirms the session and `approved = true` — they're not sitting in the page source like a client-side password gate would be.
- Downloadable resources use **signed URLs** (expire after 1 hour), so links can't be shared indefinitely.
- Rotate the anon key only if you regenerate it in Supabase; it does not need to be secret, but do keep your **service role key** (a different key, not used anywhere in this site) out of any client code — it's never referenced here.
