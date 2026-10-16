import { type Context, Hono, type Next } from "hono";
import type { AuthorizationEnv } from "../authorization/middleware";
import { problem } from "../platform/errors";

/**
 * Messaging, off for the whole server (DL-061).
 *
 * Production runs with MESSAGING_ENABLED on (DL-063: messaging launches);
 * this is the way to turn it off for everyone fast. With MESSAGING_ENABLED
 * off, this sits in front of every module:
 *
 * - starting a conversation and sending a message are refused with
 *   403 MESSAGING_DISABLED, whatever the school's own switch says, so no
 *   client can go round the app;
 * - the two places a client learns whether messaging is on - a school's
 *   content controls and a guardian's own links - say it is off, so the app
 *   offers no messaging at all.
 *
 * Reading conversations that already exist is left alone: they were written
 * while messaging was on, and stay theirs to read.
 */
export function createMessagingSwitch(): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();

  const refuse = (c: Context<AuthorizationEnv>) =>
    problem(c, "MESSAGING_DISABLED", 403, {
      detail: "Messaging is not available yet.",
    });

  routes.use("/v1/conversations", async (c, next) => {
    if (c.req.method === "POST") return refuse(c);
    await next();
  });
  routes.use("/v1/conversations/:conversationId/messages", async (c, next) => {
    if (c.req.method === "POST") return refuse(c);
    await next();
  });

  routes.use(
    "/v1/control-panel/content-controls/:schoolId",
    reportOff((body) => {
      if ("messagingEnabled" in body) body["messagingEnabled"] = false;
    }),
  );
  routes.use(
    "/v1/me/guardian-links",
    reportOff((body) => {
      const items = body["items"];
      if (!Array.isArray(items)) return;
      for (const item of items) {
        if (item && typeof item === "object") {
          (item as Record<string, unknown>)["messagingEnabled"] = false;
        }
      }
    }),
  );
  return routes;
}

/** Rewrites a successful JSON answer so it reports messaging off. */
function reportOff(
  rewrite: (body: Record<string, unknown>) => void,
): (c: Context<AuthorizationEnv>, next: Next) => Promise<void> {
  return async (c, next) => {
    await next();
    const res = c.res;
    if (
      res.status !== 200 ||
      !(res.headers.get("content-type") ?? "").includes("application/json")
    ) {
      return;
    }
    const body = await res.clone().json() as unknown;
    if (!body || typeof body !== "object" || Array.isArray(body)) return;
    rewrite(body as Record<string, unknown>);
    const headers = new Headers(res.headers);
    headers.delete("content-length");
    c.res = new Response(JSON.stringify(body), {
      status: res.status,
      headers,
    });
  };
}
