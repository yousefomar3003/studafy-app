import { corsHeaders } from "./http.ts";

export type DisabledFeature = {
  code:
    | "AI_GRADING_DISABLED"
    | "FILE_UPLOADS_DISABLED"
    | "MEETINGS_DISABLED"
    | "ACCOUNT_DELETION_PROTOTYPE_DISABLED";
  feature: "ai_grading" | "file_uploads" | "meetings" | "account_deletion";
  message: string;
};

export function disabledFeatureResponse(
  request: Request,
  disabled: DisabledFeature,
): Response {
  const requestId = crypto.randomUUID();
  console.warn(JSON.stringify({
    event: "security_capability_blocked",
    feature: disabled.feature,
    code: disabled.code,
    request_id: requestId,
    method: request.method,
    occurred_at: new Date().toISOString(),
  }));

  return new Response(
    JSON.stringify({
      error: disabled.message,
      code: disabled.code,
      request_id: requestId,
    }),
    {
      status: 503,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
        "X-Request-ID": requestId,
      },
    },
  );
}

export function rejectFileAttachment(
  request: Request,
  body: unknown,
): Response | null {
  if (
    typeof body !== "object" ||
    body === null ||
    !Object.prototype.hasOwnProperty.call(body, "attachment_path") ||
    (body as Record<string, unknown>).attachment_path === null
  ) {
    return null;
  }

  return disabledFeatureResponse(request, {
    code: "FILE_UPLOADS_DISABLED",
    feature: "file_uploads",
    message: "File attachments are temporarily unavailable.",
  });
}
