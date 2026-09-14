import { describe, expect, test } from "bun:test";
import {
  ErrorBody,
  ErrorCode,
  notImplementedError,
  ReadinessReport,
  V1AuthContextResponse,
  V1AuthDevice,
  V1AuthErrorCode,
  V1Classroom,
  V1ClassroomListResponse,
  V1ContextMembership,
  V1DeletionImpactResponse,
  V1DeletionRequestRequest,
  V1Membership,
  V1MeResponse,
  V1ReauthVerifyResponse,
} from "../src";

describe("readiness contract", () => {
  test("a ready report has no reason codes", () => {
    const parsed = ReadinessReport.parse({ ready: true, reasons: [] });
    expect(parsed.ready).toBe(true);
  });

  test("a degraded report carries stable reason codes", () => {
    const parsed = ReadinessReport.parse({
      ready: false,
      reasons: ["database_unreachable", "redis_unreachable"],
    });
    expect(parsed.reasons).toEqual([
      "database_unreachable",
      "redis_unreachable",
    ]);
  });

  test("unknown reason codes are rejected", () => {
    expect(() => ReadinessReport.parse({ ready: false, reasons: ["meh"] }))
      .toThrow();
  });
});

describe("error contract", () => {
  test("ErrorBody accepts the canonical error envelope", () => {
    const body = ErrorBody.parse({
      error: {
        code: ErrorCode.INTERNAL_ERROR,
        message: "An unexpected error occurred.",
        request_id: "00000000-0000-4000-8000-000000000001",
      },
    });
    expect(body.error.code).toBe("INTERNAL_ERROR");
  });

  test("an error without a request id is rejected", () => {
    expect(() =>
      ErrorBody.parse({ error: { code: "X", message: "y", request_id: "" } })
    ).toThrow();
  });

  test("error codes are stable machine strings", () => {
    expect(Object.values(ErrorCode).sort()).toEqual([
      "CONFLICT",
      "FORBIDDEN",
      "INTERNAL_ERROR",
      "INVALID_REQUEST",
      "MFA_REQUIRED",
      "NOT_FOUND",
      "NOT_IMPLEMENTED",
      "RATE_LIMITED",
      "REAUTH_REQUIRED",
      "UNAUTHENTICATED",
    ]);
  });

  test("no auth error code distinguishes why authentication failed", () => {
    // Anti-enumeration is a property of the vocabulary, not of one handler:
    // if a code like USER_NOT_FOUND ever exists, some handler will return it.
    const leaky = V1AuthErrorCode.options.filter((code) =>
      /USER|ACCOUNT|EMAIL|PASSWORD|PROVIDER|EXISTS|UNKNOWN|DELETED|SUSPENDED/
        .test(code)
    );
    expect(leaky).toEqual([]);
  });

  test("notImplementedError matches the /v1 empty-router contract", () => {
    const error = notImplementedError("req-1");
    expect(ErrorBody.parse({ error })).toEqual({
      error: {
        code: "NOT_IMPLEMENTED",
        message: "No /v1 resources are implemented yet.",
        request_id: "req-1",
      },
    });
  });
});

describe("/v1 typed contracts (ARC-011)", () => {
  test("OpenAPI schemas and operations stay aligned with zod contracts", async () => {
    const specUrl = new URL("../openapi/v1.json", import.meta.url);
    const spec = await Bun.file(specUrl).json() as {
      paths: Record<string, { get: { operationId: string } }>;
      components: {
        schemas: Record<string, { properties: Record<string, unknown> }>;
      };
    };
    const schemaKeys = (name: string) =>
      Object.keys(spec.components.schemas[name]!.properties).sort();

    expect(V1Membership.keyof().options.map(String).sort()).toEqual(
      schemaKeys("V1Membership"),
    );
    expect(V1MeResponse.keyof().options.map(String).sort()).toEqual(
      schemaKeys("V1MeResponse"),
    );
    expect(V1Classroom.keyof().options.map(String).sort()).toEqual(
      schemaKeys("V1Classroom"),
    );
    expect(V1ClassroomListResponse.keyof().options.map(String).sort()).toEqual(
      schemaKeys("V1ClassroomListResponse"),
    );
    expect(spec.paths["/v1/me"]!.get.operationId).toBe("getMe");
    expect(spec.paths["/v1/classrooms"]!.get.operationId).toBe(
      "listClassrooms",
    );
  });

  test("AUTH-030 OpenAPI schemas stay aligned with their zod contracts", async () => {
    const specUrl = new URL("../openapi/v1.json", import.meta.url);
    const spec = await Bun.file(specUrl).json() as {
      paths: Record<string, Record<string, { operationId: string }>>;
      components: {
        schemas: Record<string, { properties: Record<string, unknown> }>;
      };
    };
    const schemaKeys = (name: string) =>
      Object.keys(spec.components.schemas[name]!.properties).sort();

    for (
      const [schema, name] of [
        [V1ContextMembership, "V1ContextMembership"],
        [V1AuthContextResponse, "V1AuthContextResponse"],
        [V1AuthDevice, "V1AuthDevice"],
        [V1DeletionImpactResponse, "V1DeletionImpactResponse"],
        [V1DeletionRequestRequest, "V1DeletionRequestRequest"],
        [V1ReauthVerifyResponse, "V1ReauthVerifyResponse"],
      ] as const
    ) {
      expect(schema.keyof().options.map(String).sort()).toEqual(
        schemaKeys(name),
      );
    }
  });

  test("no auth request lets the caller name a user, school, or role", () => {
    // Tenancy is derived server-side. A request field that could carry it
    // would be the bug, so the contract is asserted rather than the handler.
    const requestSchemas = {
      V1DeletionRequestRequest,
    };
    for (const [name, schema] of Object.entries(requestSchemas)) {
      const fields = schema.keyof().options.map(String);
      expect({
        name,
        leaked: fields.filter((field) =>
          /^(user_id|school_id|role|actor_id|tenant_id)$/.test(field)
        ),
      }).toEqual({ name, leaked: [] });
    }
  });

  test("V1MeResponse accepts a valid authenticated profile", () => {
    const parsed = V1MeResponse.parse({
      id: "00000000-0000-4000-8000-000000000001",
      display_name: "Rana Haddad",
      email: "rana@alnoor.edu",
      memberships: [
        {
          id: "00000000-0000-4000-8000-0000000000aa",
          school_id: "00000000-0000-4000-8000-0000000000bb",
          school_name: "Al-Noor International",
          role: "teacher",
          active: true,
        },
      ],
      environment: "development",
      active_term_id: "00000000-0000-4000-8000-0000000000cc",
    });
    expect(parsed.memberships).toHaveLength(1);
    expect(parsed.memberships[0]!.role).toBe("teacher");
  });

  test("V1MeResponse rejects an unknown role", () => {
    expect(() =>
      V1MeResponse.parse({
        id: "x",
        display_name: "x",
        email: "x",
        memberships: [
          {
            id: "x",
            school_id: "x",
            school_name: "x",
            role: "admin",
            active: true,
          },
        ],
        environment: "development",
        active_term_id: null,
      })
    ).toThrow();
  });

  test("V1ClassroomListResponse accepts a valid classroom list", () => {
    const parsed = V1ClassroomListResponse.parse({
      classrooms: [
        {
          id: "00000000-0000-4000-8000-000000000001",
          name: "Biology",
          grade: "10",
          section: "B",
          room: "Lab 2",
          student_count: 6,
          weekly_sessions: 3,
          term_name: "Term 1",
        },
      ],
    });
    expect(parsed.classrooms).toHaveLength(1);
    expect(parsed.classrooms[0]!.name).toBe("Biology");
  });

  test("V1ClassroomListResponse rejects a negative student count", () => {
    expect(() =>
      V1ClassroomListResponse.parse({
        classrooms: [
          {
            id: "x",
            name: "x",
            grade: "x",
            section: "x",
            room: null,
            student_count: -1,
            weekly_sessions: null,
            term_name: null,
          },
        ],
      })
    ).toThrow();
  });

  test(
    "the shared fixture validates against both /v1 contracts",
    async () => {
      // Resolve from this test file's directory so CWD doesn't matter.
      const fixtureUrl = new URL(
        "../../../lib/data/contracts/v1_fixture.json",
        import.meta.url,
      );
      const fixture = await Bun.file(fixtureUrl).json();
      expect(V1MeResponse.parse(fixture.me).memberships).toHaveLength(1);
      expect(
        V1ClassroomListResponse.parse(fixture.classrooms).classrooms,
      ).toHaveLength(2);
    },
  );
});
