import { disabledFeatureResponse } from "../_shared/containment.ts";
import { corsHeaders } from "../_shared/http.ts";

export function handleProposePaperGrade(request: Request): Response {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // SEC-001: Keep this unavailable until callers submit a server-owned
  // file_object_id that has passed ownership and file-security checks. Do not
  // add an environment-variable bypass for the former path-based workflow.
  return disabledFeatureResponse(request, {
    code: "AI_GRADING_DISABLED",
    feature: "ai_grading",
    message: "AI grading is temporarily unavailable.",
  });
}

if (import.meta.main) Deno.serve(handleProposePaperGrade);
