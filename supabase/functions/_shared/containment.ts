import { corsHeaders } from "./http.ts";

export type DisabledFeature = {
  code:
    | "MEETINGS_DISABLED"
    | "ACCOUNT_DELETION_PROTOTYPE_DISABLED";
  feature: "meetings" | "account_deletion";
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
