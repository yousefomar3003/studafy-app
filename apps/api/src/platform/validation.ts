import type { Context, MiddlewareHandler } from "hono";
import type { z } from "zod";
import type { V1RouteContract } from "@studafy/contracts";
import { problem } from "./errors";
import type { PlatformEnv } from "./types";

function issueCode(code: string): string {
  return code === "unrecognized_keys" ? "unknownField" : code;
}

export function validateRouteInput(
  route: V1RouteContract,
): MiddlewareHandler<PlatformEnv> {
  return async (c, next) => {
    c.set("operationId", route.operationId as never);
    c.set("idempotencyMode", route.idempotency);

    const url = new URL(c.req.url);
    const rawQuery = Object.fromEntries(url.searchParams.entries());
    if (!route.query && Object.keys(rawQuery).length > 0) {
      return problem(c, "INVALID_REQUEST", 400);
    }
    if (route.query) {
      const parsed = route.query.safeParse(rawQuery);
      if (!parsed.success) return problem(c, "INVALID_REQUEST", 400);
      c.set("validatedQuery", parsed.data);
    } else c.set("validatedQuery", undefined);

    if (route.params) {
      const parsed = route.params.safeParse(c.req.param());
      if (!parsed.success) return problem(c, "INVALID_REQUEST", 400);
      c.set("validatedParams", parsed.data);
    } else c.set("validatedParams", undefined);

    if (!route.request) {
      if (c.req.raw.body !== null) return problem(c, "INVALID_REQUEST", 400);
      c.set("validatedBody", undefined);
      await next();
      return;
    }

    let raw: unknown;
    try {
      const text = await c.req.text();
      raw = JSON.parse(text);
    } catch {
      return problem(c, "INVALID_REQUEST", 400);
    }

    const result = route.request.safeParse(raw);
    if (!result.success) {
      const allowed = new Set(
        route.request instanceof Object && "shape" in route.request
          ? Object.keys((route.request as z.ZodObject).shape)
          : [],
      );
      const errors = result.error.issues.flatMap((issue) => {
        const first = String(issue.path[0] ?? "");
        if (!first || !allowed.has(first)) return [];
        return [{
          path: issue.path.map(String).join("."),
          code: issueCode(issue.code),
        }];
      });
      return problem(c, "INVALID_REQUEST", 400, { errors });
    }
    c.set("validatedBody", result.data);
    await next();
  };
}

export function validatedBody<T>(c: Context<PlatformEnv>): T {
  return c.get("validatedBody") as T;
}

export function validatedParams<T>(c: Context<PlatformEnv>): T {
  return c.get("validatedParams") as T;
}

export function validatedQuery<T>(c: Context<PlatformEnv>): T {
  return c.get("validatedQuery") as T;
}
