import { describe, expect, test } from "bun:test";
import type { LogLevel } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import {
  createRedactingLogger,
  redactApiFields,
} from "../../src/platform/logging";

describe("API log redaction", () => {
  test("recursively redacts snake_case and camelCase sensitive fields", () => {
    const redacted = redactApiFields({
      request_id: "safe-request-id",
      route: "/v1/auth/context",
      authorization: "Bearer secret",
      nested: {
        refreshToken: "refresh-secret",
        id_token: "provider-secret",
        signedUrl: "https://signed.test/secret",
        objectPath: "user/private/file.pdf",
        receipt: "purchase-secret",
        requestBody: { password: "password-secret" },
      },
    });
    const encoded = JSON.stringify(redacted);
    expect(encoded).toContain("safe-request-id");
    expect(encoded).toContain("/v1/auth/context");
    for (
      const secret of [
        "Bearer secret",
        "refresh-secret",
        "provider-secret",
        "signed.test",
        "user/private",
        "purchase-secret",
        "password-secret",
      ]
    ) expect(encoded).not.toContain(secret);
  });

  test("error_kind survives redaction, raw error text still does not", () => {
    // The SECRET_KEYS match is a substring test, so "error_kind" collides with
    // "error". It carries a bounded enum, never exception text, and an
    // http_error line is useless without it.
    const fields = redactApiFields({
      error_kind: "unexpected",
      errorKind: "timeout",
      error: "Error: connect ECONNREFUSED 10.0.0.1:5432",
      message: "password authentication failed for user postgres",
      stack: "at Database.connect (db.ts:1)",
    });
    expect(fields["error_kind"]).toBe("unexpected");
    expect(fields["errorKind"]).toBe("timeout");
    expect(fields["error"]).toBe("<redacted>");
    expect(fields["message"]).toBe("<redacted>");
    expect(fields["stack"]).toBe("<redacted>");
    const encoded = JSON.stringify(fields);
    expect(encoded).not.toContain("ECONNREFUSED");
    expect(encoded).not.toContain("postgres");
  });

  test("access-log identity fields are not mistaken for secrets", () => {
    const fields = redactApiFields({
      user_id: "6feeb429-05b0-406f-8b9b-90a466cff2d8",
      ip_hash: "v1:abc123",
      ua_family: "ios",
    });
    expect(fields["user_id"]).toBe("6feeb429-05b0-406f-8b9b-90a466cff2d8");
    expect(fields["ip_hash"]).toBe("v1:abc123");
    expect(fields["ua_family"]).toBe("ios");
  });

  test("the logger wrapper also redacts bound child fields", () => {
    const collector = new LogCollector();
    const logger = createRedactingLogger(
      createJsonLogger("api", "test", "debug" as LogLevel, collector.sink),
    );
    logger.child({ cookie: "session=secret" }).error("unsafe_exception", {
      stack: "Error: SQL SELECT private_table at source.ts:1",
      accessToken: "access-secret",
    });
    const line = collector.lines.join("\n");
    expect(line).not.toContain("session=secret");
    expect(line).not.toContain("access-secret");
    expect(line).not.toContain("private_table");
    expect(line).not.toContain("source.ts");
  });
});
