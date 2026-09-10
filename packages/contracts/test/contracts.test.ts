import { describe, expect, test } from "bun:test";
import {
  ErrorBody,
  ErrorCode,
  ReadinessReport,
  notImplementedError,
  V1MeResponse,
  V1ClassroomListResponse,
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
    expect(() =>
      ReadinessReport.parse({ ready: false, reasons: ["meh"] }),
    ).toThrow();
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
      ErrorBody.parse({ error: { code: "X", message: "y", request_id: "" } }),
    ).toThrow();
  });

  test("error codes are stable machine strings", () => {
    expect(Object.values(ErrorCode).sort()).toEqual([
      "INTERNAL_ERROR",
      "NOT_FOUND",
      "NOT_IMPLEMENTED",
    ]);
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
      }),
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
      }),
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
