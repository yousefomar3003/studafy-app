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
