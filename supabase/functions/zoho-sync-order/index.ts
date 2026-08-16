// Supabase Edge Function: zoho-sync-order
//
// Creates a Sales Order in Zoho Inventory from a Vinnie's Oil Australia
// reseller order. Called from pages/admin.html via
// supabase.functions.invoke('zoho-sync-order', { body: { order_id } }).
//
// Deploy with:
//   supabase functions deploy zoho-sync-order
//
// Required secrets (set with `supabase secrets set NAME=value`):
//   ZOHO_CLIENT_ID
//   ZOHO_CLIENT_SECRET
//   ZOHO_REFRESH_TOKEN
//   ZOHO_ORGANIZATION_ID
//   ZOHO_ACCOUNTS_DOMAIN   e.g. accounts.zoho.com.au
//   ZOHO_API_DOMAIN        e.g. www.zohoapis.com.au
//   SUPABASE_URL           (usually already set automatically)
//   SUPABASE_SERVICE_ROLE_KEY  (set manually — needed to read/write past RLS)
//
// See PORTAL-SETUP.md for how to obtain the Zoho values above.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Missing Authorization header", 401);
    }

    // Client bound to the caller's own JWT — used only to verify they're an
    // authenticated admin before we do anything with elevated privileges.
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !user) {
      return jsonError("Not authenticated", 401);
    }

    const { data: callerProfile, error: profileErr } = await callerClient
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (profileErr || callerProfile?.role !== "admin") {
      return jsonError("Admin access required", 403);
    }

    const { order_id } = await req.json();
    if (!order_id) {
      return jsonError("order_id is required", 400);
    }

    // Service-role client — bypasses RLS so we can read/write orders and
    // update the sync status regardless of row ownership.
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { data: order, error: orderErr } = await admin
      .from("orders")
      .select("*")
      .eq("id", order_id)
      .single();
    if (orderErr || !order) return jsonError("Order not found", 404);

    const { data: items, error: itemsErr } = await admin
      .from("order_items")
      .select("*")
      .eq("order_id", order_id);
    if (itemsErr) return jsonError("Could not load order items", 500);

    const { data: reseller, error: resellerErr } = await admin
      .from("profiles")
      .select("zoho_contact_id, business_name, email")
      .eq("id", order.reseller_id)
      .single();
    if (resellerErr || !reseller) return jsonError("Reseller profile not found", 404);

    if (!reseller.zoho_contact_id) {
      await markFailed(admin, order_id, "Reseller has no zoho_contact_id set — add it in Table Editor → profiles before syncing.");
      return jsonError("Reseller is not linked to a Zoho Contact yet. Set profiles.zoho_contact_id for this reseller first.", 422);
    }

    const skus = items.map((i: any) => i.sku);
    const { data: priceRows } = await admin
      .from("wholesale_prices")
      .select("sku, zoho_item_id")
      .in("sku", skus);
    const zohoItemBySku: Record<string, string | null> = {};
    (priceRows || []).forEach((p: any) => { zohoItemBySku[p.sku] = p.zoho_item_id; });

    const missingItemIds = items.filter((i: any) => !zohoItemBySku[i.sku]);
    if (missingItemIds.length > 0) {
      const skuList = missingItemIds.map((i: any) => i.sku).join(", ");
      await markFailed(admin, order_id, "Missing zoho_item_id for SKUs: " + skuList + " — set them in Table Editor → wholesale_prices before syncing.");
      return jsonError("Some products aren't linked to a Zoho Item yet: " + skuList, 422);
    }

    await admin.from("orders").update({ zoho_sync_status: "syncing" }).eq("id", order_id);

    const accessToken = await getZohoAccessToken();

    const zohoLineItems = items.map((i: any) => ({
      item_id: zohoItemBySku[i.sku],
      name: i.product_name + (i.size ? " — Size " + i.size : ""),
      description: i.size ? "Size: " + i.size : undefined,
      rate: Number(i.unit_price_aud),
      quantity: i.qty,
    }));

    const apiDomain = Deno.env.get("ZOHO_API_DOMAIN")!;
    const orgId = Deno.env.get("ZOHO_ORGANIZATION_ID")!;

    const zohoRes = await fetch(
      `https://${apiDomain}/inventory/v1/salesorders?organization_id=${orgId}`,
      {
        method: "POST",
        headers: {
          "Authorization": `Zoho-oauthtoken ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          customer_id: reseller.zoho_contact_id,
          reference_number: order.po_number,
          line_items: zohoLineItems,
          notes: order.notes || undefined,
        }),
      }
    );

    const zohoBody = await zohoRes.json();

    if (!zohoRes.ok || zohoBody.code !== 0) {
      const errMsg = zohoBody.message || `Zoho API returned ${zohoRes.status}`;
      await markFailed(admin, order_id, errMsg);
      return jsonError("Zoho sync failed: " + errMsg, 502);
    }

    const zohoSalesOrderId = zohoBody.salesorder?.salesorder_id;
    const zohoSalesOrderNumber = zohoBody.salesorder?.salesorder_number;

    await admin
      .from("orders")
      .update({
        zoho_sales_order_id: zohoSalesOrderNumber || zohoSalesOrderId,
        zoho_sync_status: "synced",
        zoho_sync_error: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", order_id);

    return new Response(
      JSON.stringify({ zoho_sales_order_id: zohoSalesOrderNumber || zohoSalesOrderId }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("zoho-sync-order error:", err);
    return jsonError("Unexpected error: " + (err?.message || String(err)), 500);
  }
});

async function getZohoAccessToken(): Promise<string> {
  const clientId = Deno.env.get("ZOHO_CLIENT_ID")!;
  const clientSecret = Deno.env.get("ZOHO_CLIENT_SECRET")!;
  const refreshToken = Deno.env.get("ZOHO_REFRESH_TOKEN")!;
  const accountsDomain = Deno.env.get("ZOHO_ACCOUNTS_DOMAIN")!;

  const res = await fetch(
    `https://${accountsDomain}/oauth/v2/token?refresh_token=${refreshToken}&client_id=${clientId}&client_secret=${clientSecret}&grant_type=refresh_token`,
    { method: "POST" }
  );
  const body = await res.json();
  if (!res.ok || !body.access_token) {
    throw new Error("Failed to refresh Zoho access token: " + (body.error || JSON.stringify(body)));
  }
  return body.access_token;
}

async function markFailed(admin: any, orderId: number, message: string) {
  await admin
    .from("orders")
    .update({ zoho_sync_status: "failed", zoho_sync_error: message, updated_at: new Date().toISOString() })
    .eq("id", orderId);
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" },
  });
}
