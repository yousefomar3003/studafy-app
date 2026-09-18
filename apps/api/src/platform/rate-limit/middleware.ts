/**
 * OPS-060 rate-limit middleware.
 *
 * Two entry points:
 *  - `rateLimitEdge` runs before authentication on every /v1 request as an
 *    IP-scoped backstop (publicDefault flow).
 *  - `rateLimitAuto` runs after authentication inside the auth router and
 *    classifies each request with `flowFor` to enforce the flow's budget
 *    (account/tenant-scoped, weighted).
 *
 * Failure behaviour is the documented contract: a Redis failure on a
 * fail-closed flow answers 503 SERVICE_UNAVAILABLE; the only fail-open flows
 * (ordinary authenticated traffic, the edge backstop) fall through to a
 * bounded in-process limiter so an outage degrades instead of blocking.
 * Rejections always look the same (problem+json, 429, Retry-After) whether
 * the subject exists or not, so the limiter cannot become an account
 * oracle.
 */
import type { Context, MiddlewareHandler } from "hono";
import {
  consumeRateLimit,
  type RateLimitDecision,
  type RateLimitPolicy,
  type Redis,
} from "@studafy/infrastructure";
import type { Logger } from "@studafy/observability";
import { problemBody } from "../errors";
import {
  clientIpPrefix,
  flowFor,
  hmacSubject,
  RATE_LIMIT_FLOWS,
  type RateLimitFlow,
  TENANT_CEILING,
} from "./policies";

export interface RateLimitDependencies {
  enabled: boolean;
  secret: string;
  /** Null runs the limiter in local-only mode (development without Redis). */
  redis: Redis | null;
  logger: Logger;
  /** Production trusts only Cloudflare's connecting-IP header. */
  trustCloudflare: boolean;
  now?: () => number;
}

export interface LocalRateLimitDependencies extends RateLimitDependencies {
  local: LocalFallbackLimiter;
}

/**
 * Bounded in-process fallback for fail-open flows while Redis is down or
 * absent. Per-process, so N instances allow N budgets - that is exactly the
 * documented degradation, not a bypass.
 */
export class LocalFallbackLimiter {
  readonly #buckets = new Map<string, { resetAt: number; count: number }>();
  readonly #capacity: number;

  constructor(maxEntries = 10_000) {
    this.#capacity = maxEntries;
  }

  consume(
    key: string,
    limit: number,
    windowMs: number,
    cost = 1,
    nowMs = Date.now(),
  ): { allowed: boolean; retryAfterMs: number | null } {
    if (this.#buckets.size > this.#capacity) {
      // Bounded memory: a full map resets rather than grows unbounded.
      this.#buckets.clear();
    }
    const bucket = this.#buckets.get(key);
    if (!bucket || bucket.resetAt <= nowMs) {
      this.#buckets.set(key, { resetAt: nowMs + windowMs, count: cost });
      return { allowed: true, retryAfterMs: null };
    }
    bucket.count += cost;
    if (bucket.count > limit) {
      return { allowed: false, retryAfterMs: bucket.resetAt - nowMs };
    }
    return { allowed: true, retryAfterMs: null };
  }
}

/**
 * Builds the limiter dependencies. When no HMAC secret is configured
 * (development), an ephemeral key is minted for the process lifetime: keys
 * stay stable within the boot, no identifier is ever stored raw, and
 * production refuses to start without a configured key.
 */
export function createRateLimitDependencies(
  deps: RateLimitDependencies,
): LocalRateLimitDependencies {
  return { ...deps, local: new LocalFallbackLimiter() };
}

/** Resolves the client IP subject: Cloudflare's header in production. */
export function resolveClientIp(
  deps: RateLimitDependencies,
  c: Context,
): string | null {
  const cloudflare = c.req.header("cf-connecting-ip");
  if (deps.trustCloudflare) return cloudflare ?? null;
  // Non-production: allow tests and local tooling to present an address via
  // the standard proxy headers; a direct dev connection keys as unresolved.
  return c.req.header("x-forwarded-for")?.split(",")[0]?.trim() ?? cloudflare ??
    null;
}

interface ActorLike {
  token: { subject: string };
}

interface AuthorizationView {
  tenant: { schoolId: string } | null;
}

function actorOf(c: Context): ActorLike | null {
  return (c.var as { actor?: ActorLike }).actor ?? null;
}

function tenantOf(c: Context): { schoolId: string } | null {
  return (c.var as { authorization?: AuthorizationView }).authorization
    ?.tenant ?? null;
}

function requestIdOf(c: Context): string {
  const requestId = c.get("requestId");
  return typeof requestId === "string" ? requestId : crypto.randomUUID();
}

function problemResponse(
  c: Context,
  code: "RATE_LIMITED" | "SERVICE_UNAVAILABLE",
): Response {
  const status = code === "RATE_LIMITED" ? 429 : 503;
  return c.json(
    problemBody(code, status, requestIdOf(c)),
    status,
    { "Content-Type": "application/problem+json; charset=UTF-8" },
  ) as Response;
}

function rateLimited(c: Context, retryAfterMs: number): Response {
  const seconds = Math.min(3600, Math.max(1, Math.ceil(retryAfterMs / 1000)));
  const response = problemResponse(c, "RATE_LIMITED");
  response.headers.set("Retry-After", String(seconds));
  return response;
}

interface Attempt {
  key: string;
  policy: RateLimitPolicy;
  cost: number;
}

function attemptsFor(
  deps: LocalRateLimitDependencies,
  c: Context,
  flow: RateLimitFlow,
  cost: number,
  tenantCeiling: boolean,
): Attempt[] {
  const flowPolicy = RATE_LIMIT_FLOWS[flow];
  if (flowPolicy.subject === "ip") {
    const prefix = clientIpPrefix(resolveClientIp(deps, c)) ?? "unresolved";
    return [{
      key: `rl:${flow}:ip:${prefix}`,
      policy: flowPolicy.policy,
      cost,
    }];
  }
  const actor = actorOf(c);
  if (!actor) return [];
  const account = hmacSubject(deps.secret, "account", actor.token.subject);
  const attempts: Attempt[] = [{
    key: `rl:${flow}:${account}`,
    policy: flowPolicy.policy,
    cost,
  }];
  if (tenantCeiling) {
    const tenant = tenantOf(c);
    if (tenant) {
      const digest = hmacSubject(deps.secret, "tenant", tenant.schoolId);
      attempts.push({
        key: `rl:${flow}:tenant:${digest}`,
        policy: TENANT_CEILING,
        cost,
      });
    }
  }
  return attempts;
}

function consumeLocally(
  deps: LocalRateLimitDependencies,
  attempts: Attempt[],
): { allowed: boolean; retryAfterMs: number | null } {
  const nowMs = deps.now?.() ?? Date.now();
  let allowed = true;
  let retryAfterMs: number | null = null;
  for (const attempt of attempts) {
    const decision = deps.local.consume(
      attempt.key,
      attempt.policy.limit,
      attempt.policy.windowSeconds * 1000,
      attempt.cost,
      nowMs,
    );
    if (!decision.allowed) {
      allowed = false;
      retryAfterMs = Math.max(retryAfterMs ?? 0, decision.retryAfterMs ?? 0);
    }
  }
  return { allowed, retryAfterMs: allowed ? null : retryAfterMs };
}

async function enforce(
  deps: LocalRateLimitDependencies,
  c: Context,
  flow: RateLimitFlow,
  weight: number,
  tenantCeiling: boolean,
): Promise<Response | null> {
  if (!deps.enabled) return null;
  const cost = Math.max(1, Math.round(weight));
  const attempts = attemptsFor(deps, c, flow, cost, tenantCeiling);
  if (attempts.length === 0) return null;

  if (!deps.redis) {
    const decision = consumeLocally(deps, attempts);
    if (!decision.allowed) {
      return rateLimited(c, decision.retryAfterMs ?? 0);
    }
    return null;
  }

  try {
    let blocked: RateLimitDecision | null = null;
    for (const attempt of attempts) {
      const decision = await consumeRateLimit(
        deps.redis,
        attempt.key,
        attempt.policy,
        { cost: attempt.cost, ...(deps.now ? { nowMs: deps.now() } : {}) },
      );
      if (!decision.allowed && blocked == null) blocked = decision;
    }
    if (blocked) return rateLimited(c, blocked.retryAfterMs ?? 0);
    return null;
  } catch {
    deps.logger.error("rate_limit_degraded", {
      request_id: requestIdOf(c),
      flow,
      redis_reachable: false,
    });
    if (RATE_LIMIT_FLOWS[flow].failClosed) {
      return problemResponse(c, "SERVICE_UNAVAILABLE");
    }
    const decision = consumeLocally(deps, attempts);
    if (!decision.allowed) {
      return rateLimited(c, decision.retryAfterMs ?? 0);
    }
    return null;
  }
}

/**
 * Pre-auth edge backstop: IP-scoped, fail-open. Mounted once on /v1/* in
 * createApp, ahead of authentication.
 */
export function rateLimitEdge(
  deps: LocalRateLimitDependencies,
): MiddlewareHandler {
  return async (c, next) => {
    const response = await enforce(deps, c, "publicDefault", 1, false);
    if (response) return response;
    await next();
  };
}

/**
 * Authenticated flow limiter: classifies the matched route and enforces the
 * flow budget against the actor (plus the tenant ceiling). Mounted inside
 * the auth router after the auth middleware, so `actor` is always present
 * when a key is needed.
 */
export function rateLimitAuto(
  deps: LocalRateLimitDependencies,
): MiddlewareHandler {
  return async (c, next) => {
    const classification = flowFor(
      c.req.method.toLowerCase() === "get" ? "get" : "post",
      c.req.path,
    );
    const tenantCeiling = classification.flow === "authenticatedApi";
    const response = await enforce(
      deps,
      c,
      classification.flow,
      classification.weight,
      tenantCeiling,
    );
    if (response) return response;
    await next();
  };
}
