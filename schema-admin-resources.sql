-- ═══════════════════════════════════════════════════════════
-- Vinnie's Oil Australia — Admin-managed Dealer Resources
-- Run in Supabase SQL Editor AFTER schema-admin-extras.sql.
--
-- The `resources` table (SDS docs, guides, marketing kit, product image
-- gallery) previously only had a read policy for approved users — admins
-- had to add/edit rows and upload files via Table Editor + Storage
-- manually. This adds write access for admins so it can be managed from
-- the Admin UI's new "Dealer Resources" tab instead.
-- ═══════════════════════════════════════════════════════════

create policy "resources: admin insert"
  on public.resources for insert
  with check (public.is_admin());

create policy "resources: admin update"
  on public.resources for update
  using (public.is_admin());

create policy "resources: admin delete"
  on public.resources for delete
  using (public.is_admin());

-- Admins can upload/replace/remove files in the dealer-resources bucket
-- (approved-user read access already exists from schema.sql).
create policy "dealer-resources: admin insert"
  on storage.objects for insert
  with check (bucket_id = 'dealer-resources' and public.is_admin());

create policy "dealer-resources: admin update"
  on storage.objects for update
  using (bucket_id = 'dealer-resources' and public.is_admin());

create policy "dealer-resources: admin delete"
  on storage.objects for delete
  using (bucket_id = 'dealer-resources' and public.is_admin());
