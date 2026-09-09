import {
  assert,
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleProposePaperGrade } from "./index.ts";

Deno.test("OPTIONS remains available for preflight", async () => {
  const response = handleProposePaperGrade(
    new Request("http://localhost/propose-paper-grade", { method: "OPTIONS" }),
  );
  assertEquals(response.status, 200);
  assertEquals(await response.text(), "ok");
});

Deno.test("caller-selected paths fail closed without being echoed", async () => {
  const substitutedPath = "papers/another-user/private-school-file.pdf";
  const response = handleProposePaperGrade(
    new Request(
      "http://localhost/propose-paper-grade",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          submission_id: "other-school-submission",
          private_scan_path: substitutedPath,
          strictness: "balanced",
        }),
      },
    ),
  );

  assertEquals(response.status, 503);
  assertEquals(response.headers.get("Cache-Control"), "no-store");
  const body = await response.json();
  assertEquals(body.code, "AI_GRADING_DISABLED");
  assertEquals(body.error, "AI grading is temporarily unavailable.");
  assertMatch(body.request_id, /^[0-9a-f-]{36}$/i);
  assert(!JSON.stringify(body).includes(substitutedPath));
});
