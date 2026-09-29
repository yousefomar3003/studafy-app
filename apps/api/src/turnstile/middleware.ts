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
    // No token at all is a request for one; a token that fails verification
    // stays a flat refusal, so a bad solve is not told how to do better.
    if (typeof token !== "string" || token.length === 0) {
      return problem(c, "CAPTCHA_REQUIRED", 403);
    }
    if (!await verifyTurnstile(options, token, fetcher)) {
      return problem(c, "FORBIDDEN", 403);
    }
    await next();
  };
}
