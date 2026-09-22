import type { MiddlewareHandler } from "hono";
import type { AuthorizationEnv } from "../authorization/middleware";
import { problem } from "../platform/errors";
import {
  type SiteverifyFetch,
  type TurnstileOptions,
  verifyTurnstile,
} from "./verification";

/** Runs inside the authenticated router, before idempotency and the lookup. */
export function requireStudentLookupChallenge(
  options: TurnstileOptions,
  fetcher?: SiteverifyFetch,
): MiddlewareHandler<AuthorizationEnv> {
  return async (c, next) => {
    let token: unknown;
    try {
      token = (await c.req.json()).captchaToken;
    } catch { /* malformed or missing input fails closed */ }
    if (!await verifyTurnstile(options, token, fetcher)) {
      return problem(c, "FORBIDDEN", 403);
    }
    await next();
  };
}
