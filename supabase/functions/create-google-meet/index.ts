import { disabledFeatureResponse } from "../_shared/containment.ts";
import { corsHeaders } from "../_shared/http.ts";

export function handleCreateGoogleMeet(request: Request): Response {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // API-042: private.api042_command's requestMeeting is the authoritative
  // replacement (packages/contracts V1RequestMeetingRequest,
  // supabase/migrations/202609160006_api042_meetings.sql,
  // supabase/tests/api042_meetings.sql). This prototype resolved recipients
  // with a guardian_links lookup per student, then an auth.admin lookup per
  // recipient (N+1 both ways), used a service-role client without
  // application-level authorization, and had no idempotency guarantee
  // beyond an unenforced client-supplied key. Never deploy this function as
  // the production backend; do not add an environment-variable bypass.
  return disabledFeatureResponse(request, {
    code: "MEETINGS_DISABLED",
    feature: "meetings",
    message:
      "This endpoint is retired. Meetings are created through POST /v1/classrooms/{classroomId}/meetings.",
  });
}

if (import.meta.main) Deno.serve(handleCreateGoogleMeet);
