import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { disabledFeatureResponse } from "./containment.ts";

Deno.test("disabled capabilities fail closed with a stable response", async () => {
  const response = disabledFeatureResponse(
    new Request("http://localhost/create-google-meet", { method: "POST" }),
    {
      code: "MEETINGS_DISABLED",
      feature: "meetings",
      message: "Meetings are temporarily unavailable.",
    },
  );

  assertEquals(response.status, 503);
  assertEquals(response.headers.get("Cache-Control"), "no-store");
  const body = await response.json();
  assertEquals(body.code, "MEETINGS_DISABLED");
  assertEquals(body.error, "Meetings are temporarily unavailable.");
  assertMatch(body.request_id, /^[0-9a-f-]{36}$/i);
  assertEquals(response.headers.get("X-Request-ID"), body.request_id);
});
