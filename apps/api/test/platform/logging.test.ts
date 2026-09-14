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
