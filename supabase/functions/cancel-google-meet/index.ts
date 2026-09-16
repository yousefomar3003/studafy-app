import { disabledFeatureResponse } from "../_shared/containment.ts";
import { corsHeaders } from "../_shared/http.ts";

export function handleCancelGoogleMeet(request: Request): Response {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // API-042: private.api042_command's cancelMeeting is the authoritative
  // replacement (POST /v1/meetings/{meetingId}/cancel,
  // supabase/migrations/202609160006_api042_meetings.sql,
  // supabase/tests/api042_meetings.sql). Never deploy this function as the
  // production backend; do not add an environment-variable bypass.
  return disabledFeatureResponse(request, {
    code: "MEETINGS_DISABLED",
    feature: "meetings",
    message:
      "This endpoint is retired. Meetings are cancelled through POST /v1/meetings/{meetingId}/cancel.",
  });
}

if (import.meta.main) Deno.serve(handleCancelGoogleMeet);
