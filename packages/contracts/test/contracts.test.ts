import { describe, expect, test } from "bun:test";
import {
  ErrorBody,
  ErrorCode,
  ReadinessReport,
  notImplementedError,
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
