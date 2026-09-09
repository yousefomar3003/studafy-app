import {
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { rejectFileAttachment } from "./containment.ts";

Deno.test("present attachment paths fail closed with a stable response", async () => {
  const response = rejectFileAttachment(
    new Request("http://localhost/study-coach", { method: "POST" }),
    { attachment_path: "coach/another-user/private.pdf" },
  );

  assertEquals(response?.status, 503);
  const body = await response!.json();
  assertEquals(body.code, "FILE_UPLOADS_DISABLED");
  assertEquals(body.error, "File attachments are temporarily unavailable.");
  assertMatch(body.request_id, /^[0-9a-f-]{36}$/i);
});

Deno.test("missing or null attachment paths preserve text-only requests", () => {
  const request = new Request("http://localhost/study-coach", {
    method: "POST",
  });
  assertEquals(
    rejectFileAttachment(request, { question: "Explain this" }),
    null,
  );
  assertEquals(
    rejectFileAttachment(request, {
      question: "Explain this",
      attachment_path: null,
    }),
    null,
  );
});
