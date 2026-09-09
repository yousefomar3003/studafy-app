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
  const verifierUrl = Deno.env.get("PURCHASE_VERIFIER_URL");
  const verifierSecret = Deno.env.get("PURCHASE_VERIFIER_SECRET");
  if (!verifierUrl || !verifierSecret) {
    return json({ error: "Purchase verification is not configured" }, 503);
  }
  const body = await request.json();
  const response = await fetch(verifierUrl, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${verifierSecret}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ ...body, user_id: user.id }),
  });
  if (!response.ok) return json({ error: "Store rejected the purchase" }, 402);
  const verified = await response.json();
  if (!verified.active) return json({ error: "No active entitlement" }, 402);
  await service.from("subscription_entitlements").upsert({
    user_id: user.id,
    product_id: body.product_id,
    source: verified.source,
    active: true,
    expires_at: verified.expires_at,
    verified_at: new Date().toISOString(),
  });
  return json({ active: true, expires_at: verified.expires_at });
});
