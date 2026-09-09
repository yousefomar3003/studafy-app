import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/http.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  const auth = request.headers.get("Authorization") ?? "";
  const url = Deno.env.get("SUPABASE_URL")!;
  const client = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: { user } } = await client.auth.getUser();
  if (!user) return json({ error: "Authentication required" }, 401);
  const token = auth.replace(/^Bearer\s+/i, "");
  const payload = JSON.parse(
    atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")),
  );
  if (!payload.iat || Date.now() / 1000 - Number(payload.iat) > 600) {
    return json(
      { error: "Reauthentication required before account deletion" },
      401,
    );
  }
  const body = await request.json();
  if (body.confirmation !== "DELETE") {
    return json({ error: "Typed confirmation required" }, 422);
  }
  const executeAfter = new Date(Date.now() + 14 * 86400000).toISOString();
  const { data, error } = await service.from("account_deletion_requests")
    .upsert({
      user_id: user.id,
      state: "grace_period",
      requested_at: new Date().toISOString(),
      execute_after: executeAfter,
    }, { onConflict: "user_id,state" }).select("id").single();
  if (error) return json({ error: error.message }, 400);
  await service.from("audit_events").insert({
    actor_id: user.id,
    action: "account_deletion_requested",
    entity_type: "profile",
    entity_id: user.id,
    after_value: { execute_after: executeAfter },
  });
  return json({ request_id: data.id, execute_after: executeAfter });
});
