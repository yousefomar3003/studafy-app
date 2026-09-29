/**
 * Managed child accounts: the route's part of the contract. The SQL decides
 * who may do what (tested against Postgres in supabase/tests); these check
 * what the route does around it - above all, that a refusal never leaves an
 * identity behind and that a sign-in token is never stored or cached.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { createJsonLogger } from "@studafy/observability";
import {
  type CreatedChild,
  ManagedAccountError,
  type ManagedAccountIssuer,
} from "@studafy/infrastructure";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import type {
  ManagedAccountOperation,
  ManagedAccountRepository,
  MirroredIdentity,
} from "../../src/managed-accounts/repository";
import { createManagedAccountRoutes } from "../../src/managed-accounts/routes";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";

const PARENT = "00000000-0000-4000-8000-00000000aa01";
const CHILD = "00000000-0000-4000-8000-00000000aa02";

class Repository implements ManagedAccountRepository {
  calls: [ManagedAccountOperation, Record<string, unknown>][] = [];
  mirrored: MirroredIdentity[] = [];
  constructor(
    readonly outcomes: Partial<Record<ManagedAccountOperation, string>> = {},
  ) {}

  async call(
    _context: unknown,
    operation: ManagedAccountOperation,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    this.calls.push([operation, input]);
    const outcome = this.outcomes[operation] ?? "ok";
    if (outcome !== "ok") return { outcome };
    if (operation === "register") {
      return {
        outcome,
        childId: input["childId"],
        displayName: "Sara",
        createdAt: "2026-09-28T15:00:00Z",
      };
    }
    if (operation === "list") {
      return {
        outcome,
        items: [{
          childId: CHILD,
          displayName: "Sara",
          createdAt: "2026-09-28T15:00:00+00:00",
        }],
      };
    }
    return { outcome };
  }

  mirrorIdentity = async (identity: MirroredIdentity) => {
    this.mirrored.push(identity);
  };
}

class Issuer implements ManagedAccountIssuer {
  created: string[] = [];
  deleted: string[] = [];
  tokensIssued = 0;
  constructor(readonly failSignIn?: ManagedAccountError["kind"]) {}

  async createChild(displayName: string): Promise<CreatedChild> {
    this.created.push(displayName);
    return { id: CHILD, email: `child-x@managed.studafy.invalid` };
  }
  async signInToken(): Promise<string> {
    if (this.failSignIn) throw new ManagedAccountError(this.failSignIn);
    this.tokensIssued += 1;
    return "h".repeat(56);
  }
  async deleteChild(childId: string): Promise<void> {
    this.deleted.push(childId);
  }
}

function app(repository: Repository, issuer: Issuer) {
  const logger = createJsonLogger("api", "test", "error");
  const routes = new Hono<AuthorizationEnv>();
  routes.use("*", async (c, next) => {
    c.set("requestId", crypto.randomUUID());
    c.set("actor", {
      token: {
        subject: PARENT,
        sessionId: null,
        issuedAt: 1,
        expiresAt: 4_000_000_000,
        assuranceLevel: "aal1",
        authMethods: [],
        claims: {},
      },
      context: { userId: PARENT, memberships: [] },
      aal2: false,
      mfaRequiredByPolicy: false,
    } as unknown as Actor);
    await next();
  });
  routes.route(
    "/",
    createManagedAccountRoutes(
      { repository, issuer },
      createAuthorizationDependencies(logger),
      { repository: new FakeIdempotencyRepository(), logger },
    ),
  );
  return routes;
}

const createBody = JSON.stringify({
  displayName: "Sara",
  policyVersion: "2026-09-09",
  locale: "en",
});

function create(routes: Hono<AuthorizationEnv>) {
  return routes.request("/v1/me/managed-children", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "idempotency-key": crypto.randomUUID(),
    },
    body: createBody,
  });
}

function session(routes: Hono<AuthorizationEnv>, headers = {}) {
  return routes.request(`/v1/me/managed-children/${CHILD}/session`, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: "{}",
  });
}

describe("creating a child account", () => {
  test("creates the identity, mirrors it, registers it with the consent", async () => {
    const repository = new Repository();
    const issuer = new Issuer();
    const res = await create(app(repository, issuer));

    expect(res.status).toBe(201);
    expect(await res.json()).toEqual({
      childId: CHILD,
      displayName: "Sara",
      createdAt: "2026-09-28T15:00:00.000Z",
    });
    expect(issuer.created).toEqual(["Sara"]);
    expect(repository.mirrored[0]?.guardianId).toBe(PARENT);
    expect(repository.calls.map(([op]) => op)).toEqual([
      "can_create",
      "register",
    ]);
    expect(repository.calls[1]?.[1]).toEqual({
      childId: CHILD,
      policyVersion: "2026-09-09",
      locale: "en",
    });
  });

  test("at the limit, no identity is created at all", async () => {
    const issuer = new Issuer();
    const res = await create(
      app(new Repository({ can_create: "limit_reached" }), issuer),
    );

    expect(res.status).toBe(409);
    expect((await res.json() as { code: string }).code).toBe(
      "MANAGED_CHILD_LIMIT",
    );
    expect(issuer.created).toEqual([]);
  });

  test("a refused registration removes the identity it made", async () => {
    const issuer = new Issuer();
    const res = await create(
      app(new Repository({ register: "invalid" }), issuer),
    );

    expect(res.status).toBe(400);
    expect(issuer.deleted).toEqual([CHILD]);
  });

  test("a managed account cannot create one", async () => {
    const issuer = new Issuer();
    const res = await create(
      app(new Repository({ can_create: "forbidden" }), issuer),
    );

    expect(res.status).toBe(403);
    expect(issuer.created).toEqual([]);
  });
});

describe("signing in as a child", () => {
  test("the managing parent gets a one-time token that nothing caches", async () => {
    const res = await session(app(new Repository(), new Issuer()));

    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toBe("no-store");
    expect((await res.json() as { tokenHash: string }).tokenHash).toHaveLength(
      56,
    );
  });

  test("anyone else is told there is no such account, and no token exists", async () => {
    const issuer = new Issuer();
    const res = await session(
      app(new Repository({ authorize_session: "not_found" }), issuer),
    );

    expect(res.status).toBe(404);
    expect(issuer.tokensIssued).toBe(0);
  });

  test("an account that is not a managed one is never entered", async () => {
    const res = await session(
      app(new Repository(), new Issuer("not_managed")),
    );
    expect(res.status).toBe(404);
  });

  test("an idempotency key is refused, so the token can never be replayed", async () => {
    const issuer = new Issuer();
    const res = await session(app(new Repository(), issuer), {
      "idempotency-key": crypto.randomUUID(),
    });

    expect(res.status).toBe(400);
    expect(issuer.tokensIssued).toBe(0);
  });
});

describe("listing", () => {
  test("lists the caller's children", async () => {
    const res = await app(new Repository(), new Issuer()).request(
      "/v1/me/managed-children",
    );
    expect(res.status).toBe(200);
    expect(
      (await res.json() as { items: { displayName: string }[] }).items[0]
        ?.displayName,
    ).toBe("Sara");
  });
});
