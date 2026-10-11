import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { apiEnvSchema, enforceApiFailClosed } from "@studafy/config";
import {
  type SiteverifyFetch,
  verifyTurnstile,
} from "../../src/turnstile/verification";
import { requireStudentLookupChallenge } from "../../src/turnstile/middleware";
import { createTurnstilePage } from "../../src/turnstile/page";
import { secureResponseHeaders } from "../../src/platform/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";

const options = {
  secret: "server-secret",
  siteKey: "public-sitekey",
  hostnames: ["api.example.com"],
};
const result = (body: unknown, status = 200): SiteverifyFetch => async () =>
  Response.json(body, { status });

describe("Turnstile", () => {
  test("requires success, exact action and exact allowed hostname", async () => {
    const good = {
      success: true,
      action: "student_lookup",
      hostname: "api.example.com",
    };
    expect(await verifyTurnstile(options, "token", result(good))).toBe(true);
    for (
      const change of [
        { success: false },
        { success: "true" },
        { action: "login" },
        { hostname: "api.example.com.evil.test" },
        { hostname: "localhost" },
        { hostname: undefined },
      ]
    ) {
      expect(
        await verifyTurnstile(options, "token", result({ ...good, ...change })),
      ).toBe(false);
    }
  });
  test("a testing-key answer counts only where testing keys are allowed", async () => {
    // What siteverify returns for Cloudflare's always-pass testing secret:
    // no action, and a testing marker.
    const testing = {
      success: true,
      hostname: "example.com",
      metadata: { result_with_testing_key: true },
    };
    const dev = { ...options, hostnames: ["example.com"] };
    expect(await verifyTurnstile(dev, "token", result(testing))).toBe(false);
    expect(
      await verifyTurnstile(
        { ...dev, allowTestingKeys: true },
        "token",
        result(testing),
      ),
    ).toBe(true);
    // Still an exact, allowlisted hostname, and still a success.
    for (
      const change of [{ hostname: "evil.test" }, { success: false }]
    ) {
      expect(
        await verifyTurnstile(
          { ...dev, allowTestingKeys: true },
          "token",
          result({ ...testing, ...change }),
        ),
      ).toBe(false);
    }
    // A real widget's answer is unchanged by the flag: the action must match.
    expect(
      await verifyTurnstile(
        { ...options, allowTestingKeys: true },
        "token",
        result({ success: true, hostname: "api.example.com", action: "login" }),
      ),
    ).toBe(false);
  });
  test("rejects malformed tokens and unconfigured hostnames without calling Cloudflare", async () => {
    const never: SiteverifyFetch = async () => {
      throw new Error("must not run");
    };
    for (const token of [undefined, null, "", " ", 12, "x".repeat(2049)]) {
      expect(await verifyTurnstile(options, token, never)).toBe(false);
    }
    expect(await verifyTurnstile({ ...options, hostnames: [] }, "token", never))
      .toBe(false);
  });
  test("fails closed for network, upstream and malformed responses", async () => {
    const failure: SiteverifyFetch = async () => {
      throw new Error("network");
    };
    for (
      const fetcher of [
        failure,
        result({}, 503),
        async () => new Response("invalid"),
        result(null),
      ]
    ) {
      expect(await verifyTurnstile(options, "token", fetcher)).toBe(false);
    }
  });
  test("sends the secret only in the siteverify body and sets a timeout", async () => {
    await verifyTurnstile(options, "token", async (url, init) => {
      expect(url).toBe(
        "https://challenges.cloudflare.com/turnstile/v0/siteverify",
      );
      expect(init.method).toBe("POST");
      expect(init.signal).toBeInstanceOf(AbortSignal);
      expect((init.body as URLSearchParams).get("secret")).toBe(options.secret);
      expect((init.body as URLSearchParams).get("response")).toBe("token");
      return Response.json({ success: false });
    });
  });
  test("a rejected or replayed token never reaches the protected handler", async () => {
    const app = new Hono<AuthorizationEnv>();
    let used = false;
    let writes = 0;
    app.use(
      "*",
      requireStudentLookupChallenge(options, async () => {
        const success = !used;
        used = true;
        return Response.json({
          success,
          action: "student_lookup",
          hostname: "api.example.com",
        });
      }),
    );
    app.post("/v1/students/locate", (c) => {
      writes++;
      return c.json({ found: true });
    });
    const send = (body: unknown) =>
      app.request("/v1/students/locate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
    expect((await send({})).status).toBe(403);
    expect(writes).toBe(0);
    expect((await send({ captchaToken: "fresh" })).status).toBe(200);
    expect((await send({ captchaToken: "fresh" })).status).toBe(403);
    expect(writes).toBe(1);
  });

  test("no token asks for a check; a bad token is refused flatly", async () => {
    // The app shows the check only when it sees CAPTCHA_REQUIRED, so the two
    // must not be confused: a missing token is a request for one, and a
    // failed solve is a refusal that says nothing about how to do better.
    const app = new Hono<AuthorizationEnv>();
    app.use(
      "*",
      requireStudentLookupChallenge(
        options,
        async () => Response.json({ success: false }),
      ),
    );
    app.post("/v1/students/locate", (c) => c.json({ found: true }));
    const send = async (body: unknown) => {
      const res = await app.request("/v1/students/locate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      return {
        status: res.status,
        code: (await res.json() as { code: string }).code,
      };
    };
    expect(await send({})).toEqual({ status: 403, code: "CAPTCHA_REQUIRED" });
    expect(await send({ captchaToken: "" })).toEqual({
      status: 403,
      code: "CAPTCHA_REQUIRED",
    });
    expect(await send({ captchaToken: "forged" })).toEqual({
      status: 403,
      code: "FORBIDDEN",
    });
  });
  test("widget page exposes only sitekey and retains nonce-based CSP", async () => {
    const app = new Hono();
    app.use("*", secureResponseHeaders("development") as never);
    app.route("/", createTurnstilePage(options));
    const res = await app.request("/auth/bot-check?lang=ar");
    const html = await res.text();
    expect(html).toContain('dir="rtl"');
    expect(html).toContain(options.siteKey);
    expect(html).not.toContain(options.secret);
    expect(html).toContain("student_lookup");
    expect(html).toContain("turnstile.reset(widgetId)");
    expect(res.headers.get("Content-Security-Policy")).toContain(
      "script-src 'nonce-",
    );
    expect(res.headers.get("Cache-Control")).toBe("no-store");
  });
  test("enabled integration cannot start with missing or unsafe hostnames", () => {
    for (
      const host of [
        "",
        "*.example.com",
        "https://api.example.com",
        "example.com/path",
      ]
    ) {
      expect(() =>
        enforceApiFailClosed(apiEnvSchema.parse({
          ENVIRONMENT: "development",
          TURNSTILE_ENABLED: "true",
          TURNSTILE_SITE_KEY: "public",
          TURNSTILE_SECRET: "secret",
          TURNSTILE_HOSTNAMES: host,
        }))
      ).toThrow();
    }
    expect(() =>
      enforceApiFailClosed(apiEnvSchema.parse({
        ENVIRONMENT: "production",
        TURNSTILE_ENABLED: "true",
        TURNSTILE_SITE_KEY: "public",
        TURNSTILE_SECRET: "secret",
        TURNSTILE_HOSTNAMES: "localhost",
      }))
    ).toThrow("Turnstile");
  });
});
