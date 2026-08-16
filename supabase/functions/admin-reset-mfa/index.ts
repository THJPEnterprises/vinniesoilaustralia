// Supabase Edge Function: admin-reset-mfa
//
// Lets an admin clear a reseller/admin's enrolled MFA (TOTP) factors,
// for when they've lost their phone / authenticator app and are locked
// out. MFA is mandatory (see schema-mfa-enforcement.sql), so this is
// the account-recovery escape hatch — without it, a lost device would
// permanently lock someone out with no way back in.
//
// Called from pages/admin.html via
// supabase.functions.invoke('admin-reset-mfa', { body: { user_id } }).
//
// Deploy with:
//   supabase functions deploy admin-reset-mfa
//
// Requires the same SUPABASE_SERVICE_ROLE_KEY secret as the other admin
// functions (see PORTAL-SETUP.md) — set once, shared by all of them:
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

    const { user_id } = await req.json();
    if (!user_id) return jsonError("user_id is required", 400);

    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { data: targetUser, error: getErr } = await admin.auth.admin.getUserById(user_id);
    if (getErr || !targetUser?.user) {
      return jsonError("Could not find that account: " + (getErr?.message || "not found"), 404);
    }

    const factors = targetUser.user.factors || [];
    if (factors.length === 0) {
      return new Response(JSON.stringify({ removed: 0, message: "This account had no MFA factors enrolled." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let removed = 0;
    const errors: string[] = [];
    for (const factor of factors) {
      const res = await fetch(`${supabaseUrl}/auth/v1/admin/users/${user_id}/factors/${factor.id}`, {
        method: "DELETE",
        headers: {
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
      });
      if (res.ok) {
        removed++;
      } else {
        const body = await res.text();
        errors.push(`${factor.id}: ${body}`);
      }
    }

    if (errors.length > 0 && removed === 0) {
      return jsonError("Failed to remove MFA factors: " + errors.join("; "), 500);
    }

    return new Response(
      JSON.stringify({ removed, message: `Removed ${removed} MFA factor(s). They'll be prompted to set up MFA again on next sign-in.` }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("admin-reset-mfa error:", err);
    return jsonError("Unexpected error: " + (err?.message || String(err)), 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" },
  });
}
