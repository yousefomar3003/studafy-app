import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { z } from "zod";
import type { LogLevel } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import {
  requestContext,
  requestTelemetry,
} from "../../src/platform/middleware";
import { createRedactingLogger } from "../../src/platform/logging";
import { validateRouteInput } from "../../src/platform/validation";
import { problem } from "../../src/platform/errors";
import { outcomeProblem, rowErrors } from "../../src/platform/outcomes";

function harness() {
  const collector = new LogCollector();
  const logger = createRedactingLogger(
    createJsonLogger("api", "test", "debug" as LogLevel, collector.sink),
  );
  const app = new Hono();
  app.use("*", requestContext());
  app.use("*", requestTelemetry(logger));
  return { app, collector };
}

function accessLine(collector: LogCollector): Record<string, unknown> {
  const line = collector.lines.find((entry) =>
    entry.includes("http_request_completed")
  );
  return JSON.parse(line!) as Record<string, unknown>;
}

describe("a refused request says why in the access log", () => {
  test("an invalid body logs the field paths and issue codes, not values", async () => {
    const { app, collector } = harness();
    const route = {
      operationId: "createResource",
      idempotency: "optional",
      request: z.strictObject({
        title: z.string().min(1),
        links: z.array(z.strictObject({ url: z.url() })),
      }),
    };
    app.post(
      "/v1/things",
      validateRouteInput(route as never),
      (c) => c.json({}),
    );
    const response = await app.request("/v1/things", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        title: "",
        links: [{ url: "not a url: secret-value-123" }],
      }),
    });
    expect(response.status).toBe(400);
    const line = accessLine(collector);
    expect(line["problem_code"]).toBe("INVALID_REQUEST");
    expect(line["invalid_fields"]).toEqual(
      expect.arrayContaining([
        expect.stringMatching(/^title:/),
        expect.stringMatching(/^links\.0\.url:/),
      ]),
    );
    expect(collector.lines.join("\n")).not.toContain("secret-value-123");
  });

  test("other refusals log their code alone", async () => {
    const { app, collector } = harness();
    app.get("/v1/thing", (c) => problem(c, "FILE_NOT_CLEAN", 409));
    expect((await app.request("/v1/thing")).status).toBe(409);
    const line = accessLine(collector);
    expect(line["problem_code"]).toBe("FILE_NOT_CLEAN");
    expect(line["invalid_fields"]).toBeUndefined();
  });

  test("a success logs no problem fields", async () => {
    const { app, collector } = harness();
    app.get("/v1/ok", (c) => c.json({ ok: true }));
    await app.request("/v1/ok");
    expect(accessLine(collector)["problem_code"]).toBeUndefined();
  });
});

describe("a refused attachment says which one in the answer and the log", () => {
  test("the SQL rows become problem errors and invalid_fields", async () => {
    const { app, collector } = harness();
    app.post(
      "/v1/resources",
      (c) =>
        outcomeProblem(c, "attachment_refused", {}, undefined, [
          { path: "attachmentFileIds.1", reason: "file_refused" },
          { path: "questions.0.links.2", reason: "link_not_allowed" },
        ]),
    );
    const response = await app.request("/v1/resources", { method: "POST" });
    expect(response.status).toBe(422);
    const body = await response.json() as Record<string, unknown>;
    expect(body["code"]).toBe("ATTACHMENT_REFUSED");
    expect(body["errors"]).toEqual([
      { path: "attachmentFileIds.1", code: "file_refused" },
      { path: "questions.0.links.2", code: "link_not_allowed" },
    ]);
    const line = accessLine(collector);
    expect(line["problem_code"]).toBe("ATTACHMENT_REFUSED");
    expect(line["invalid_fields"]).toEqual([
      "attachmentFileIds.1:file_refused",
      "questions.0.links.2:link_not_allowed",
    ]);
  });

  test("a row that is not a request path or a fixed reason is dropped", () => {
    expect(rowErrors([
      { path: "attachmentFileIds.0", reason: "file_not_found" },
      { path: "https://evil.example.org/", reason: "link_not_allowed" },
      { path: "links.0", reason: "Some Free Text" },
      { path: "a.b.c.d.e.f.g", reason: "too_many" },
      { path: 3, reason: "duplicate" },
    ])).toEqual([{ path: "attachmentFileIds.0", code: "file_not_found" }]);
  });

  test("grade rows are still named by id", () => {
    const id = "5f470000-0000-4000-8000-0000000000e1";
    expect(rowErrors([{ studentId: id, reason: "not_enrolled" }])).toEqual([
      { path: `students/${id}`, code: "not_enrolled" },
    ]);
  });
});
