import { disabledFeatureResponse } from "../_shared/containment.ts";
import { corsHeaders } from "../_shared/http.ts";

export function handleRequestAccountDeletion(request: Request): Response {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // AUTH-030/031: /v1/account/deletion-request is the authoritative
  // replacement (apps/api/src/auth/routes.ts, ADR-0016, ADR-0017). This
  // prototype's recent-auth check manually base64-decoded the JWT payload
  // and treated "issued within the last 600 seconds" as proof of recent
  // authentication - not a real assurance check, and exactly the broken
  // iat check DL-032 replaced with a single-use hashed recent-auth grant.
  // Never deploy this function as the production backend; do not add an
  // environment-variable bypass.
  return disabledFeatureResponse(request, {
    code: "ACCOUNT_DELETION_PROTOTYPE_DISABLED",
    feature: "account_deletion",
    message:
      "This endpoint is retired. Account deletion is requested through POST /v1/account/deletion-request.",
  });
}

if (import.meta.main) Deno.serve(handleRequestAccountDeletion);
