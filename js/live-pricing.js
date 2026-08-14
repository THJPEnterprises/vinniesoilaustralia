/* Vinnie's Oil Australia — live RRP sync
   Replaces the hardcoded Recommended Retail Price on product pages with
   the live value from Supabase (public_pricing view, admin-editable via
   the Products & Pricing tab in /pages/admin.html). If Supabase is
   unreachable or the SKU isn't found, the hardcoded fallback price stays
   as-is — this never breaks the page, only enhances it. */
(function () {
  var el = document.getElementById('live-rrp-price');
  if (!el) return;
  var sku = el.getAttribute('data-sku');
  if (!sku || !window.SUPABASE_URL || !window.SUPABASE_ANON_KEY || !window.supabase) return;

  var supabase = window.supabase.createClient(window.SUPABASE_URL, window.SUPABASE_ANON_KEY);
  supabase.from('public_pricing').select('rrp_aud').eq('sku', sku).single()
    .then(function (res) {
      if (res.data && res.data.rrp_aud != null) {
        el.textContent = '$' + Number(res.data.rrp_aud).toFixed(2);
      }
    })
    .catch(function () { /* keep hardcoded fallback silently */ });
})();
