// Supabase Edge Function: admin-create-user
//
// Creates a new reseller/admin account with an admin-set temporary
// password, without exposing the service role key to the browser.
// Called from pages/admin.html via
// supabase.functions.invoke('admin-create-user', { body: {...} }).
//
// Deploy with:
//   supabase functions deploy admin-create-user
//
// Requires the same SUPABASE_SERVICE_ROLE_KEY secret as zoho-sync-order
// (see PORTAL-SETUP.md) — set once, shared by both functions:
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

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
    if (!authHeader) return jsonError("Missing Authorization header", 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !user) return jsonError("Not authenticated", 401);

    const { data: callerProfile, error: profileErr } = await callerClient
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (profileErr || callerProfile?.role !== "admin") {
      return jsonError("Admin access required", 403);
    }

    const { email, password, business_name, role, approved } = await req.json();

    if (!email || !password) return jsonError("email and password are required", 400);
    if (password.length < 6) return jsonError("Password must be at least 6 characters", 400);
    if (role && !["reseller", "wholesaler", "admin"].includes(role)) {
      return jsonError("role must be reseller, wholesaler or admin", 400);
    }

    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceRoleKey);

    // Create the auth account. This automatically triggers the
    // handle_new_user() trigger from schema.sql, which inserts a matching
    // profiles row (email only, approved=false, role='reseller' by default).
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // skip email verification — admin is vouching for this account
    });

    if (createErr) return jsonError("Failed to create account: " + createErr.message, 400);

    // Fill in the extra details the trigger doesn't set
    const { error: updateErr } = await admin
      .from("profiles")
      .update({
        business_name: business_name || null,
        role: role || "reseller",
        approved: approved !== false,
      })
      .eq("id", created.user.id);

    if (updateErr) {
      return jsonError("Account created but profile update failed: " + updateErr.message, 500);
    }

    return new Response(
      JSON.stringify({ id: created.user.id, email: created.user.email }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("admin-create-user error:", err);
    return jsonError("Unexpected error: " + (err?.message || String(err)), 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" },
  });
}
