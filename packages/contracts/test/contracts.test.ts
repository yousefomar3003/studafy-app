import { describe, expect, test } from "bun:test";
import {
  ErrorCode,
  ProblemDetails,
  ReadinessReport,
  V1AssessmentAuthoringQuestionsResponse,
  V1AssessmentQuestionsResponse,
  V1AuthContextResponse,
  V1AuthDevice,
  V1AuthErrorCode,
  V1ClassroomListResponse,
  V1ContextMembership,
  V1CreateUploadIntentRequest,
  V1DeletionImpactResponse,
  V1DeletionRequestRequest,
  V1EntitlementsResponse,
  V1Membership,
  V1MeResponse,
  V1ReauthVerifyResponse,
  V1RequestPurchaseApprovalRequest,
  v1Route,
  V1SendMessageRequest,
  V1SubmitPurchaseRequest,
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

describe("problem details contract", () => {
  test("ProblemDetails accepts the canonical error envelope", () => {
    const body = ProblemDetails.parse({
      type: "https://api.studafy.io/problems/internal-error",
      title: "Internal error",
      status: 500,
      code: ErrorCode.INTERNAL_ERROR,
      detail: "An unexpected error occurred.",
      requestId: "00000000-0000-4000-8000-000000000001",
    });
    expect(body.code).toBe("INTERNAL_ERROR");
  });

  test("an error without a request id is rejected", () => {
    expect(() =>
      ProblemDetails.parse({
        type: "https://api.studafy.io/problems/internal-error",
        title: "Internal error",
        status: 500,
        code: "INTERNAL_ERROR",
        detail: "An unexpected error occurred.",
      })
    ).toThrow();
  });

  test("error codes are stable machine strings", () => {
    expect(Object.values(ErrorCode).sort()).toEqual([
      "AI_ALLOWANCE_USED",
      "AI_DAILY_LIMIT",
      "AI_FEATURE_DISABLED",
      "ATTENDANCE_LOCKED",
      "BENEFICIARY_LINK_INVALID",
      "CAPTCHA_REQUIRED",
      "CONFLICT",
      "CONTACT_NOT_ALLOWED",
      "CURSOR_INVALID",
      "DELIVERY_GRANT_INVALID",
      "ENTITLEMENT_OWNED_BY_OTHER_ACCOUNT",
      "FILE_DELIVERY_DISABLED",
      "FILE_NOT_CLEAN",
      "FILE_PUBLISH_DISABLED",
      "FORBIDDEN",
      "GRADE_ENTRIES_INVALID",
      "GUARDIAN_LINK_REQUIRED",
      "IDEMPOTENCY_IN_PROGRESS",
      "IDEMPOTENCY_KEY_NOT_ALLOWED",
      "IDEMPOTENCY_KEY_REQUIRED",
      "IDEMPOTENCY_KEY_REUSED",
      "INTERNAL_ERROR",
      "INVALID_HEADER",
      "INVALID_REQUEST",
      "INVALID_STATE",
      "LESSON_HAS_NO_TEXT",
      "MANAGED_CHILD_LIMIT",
      "MESSAGING_DISABLED",
      "METHOD_NOT_ALLOWED",
      "MFA_REQUIRED",
      "NOT_FOUND",
      "NOT_IMPLEMENTED",
      "PARENTAL_GATE_REQUIRED",
      "PAYLOAD_TOO_LARGE",
      "PHOTO_NOT_READY",
      "PHOTO_UNREADABLE",
      "PLAN_REQUIRED",
      "PRODUCT_NOT_FOUND",
      "RATE_LIMITED",
      "REASON_REQUIRED",
      "REAUTH_REQUIRED",
      "RECEIPT_INVALID",
      "REQUEST_TIMEOUT",
      "SERVICE_UNAVAILABLE",
      "STORAGE_UNAVAILABLE",
      "STUDENT_PURCHASE_DISABLED",
      "SUBMISSION_LOCKED",
      "UNAUTHENTICATED",
      "UNSUPPORTED_MEDIA_TYPE",
      "UPLOAD_ALREADY_COMPLETED",
      "UPLOAD_CHECKSUM_MISMATCH",
      "UPLOAD_CONCURRENCY_LIMIT",
      "UPLOAD_EXPIRED",
      "UPLOAD_INCOMPLETE",
      "UPLOAD_QUOTA_EXCEEDED",
      "UPLOAD_SIZE_MISMATCH",
      "UPLOAD_TYPE_MISMATCH",
      "VERSION_CONFLICT",
      "WINDOW_CLOSED",
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
});

describe("FILE-050 upload contracts", () => {
  const common = {
    schoolId: "bbbbbbbb-0000-4000-8000-000000000001",
    displayName: "work.pdf",
    expectedSizeBytes: 128,
    declaredMediaType: "application/pdf",
    sha256: "a".repeat(64),
  };

  test("accepts only the exact target shape for each purpose", () => {
    expect(
      V1CreateUploadIntentRequest.safeParse({
        ...common,
        purpose: "assignment_submission",
        assignmentId: "cccccccc-0000-4000-8000-000000000001",
        studentId: "dddddddd-0000-4000-8000-000000000001",
      }).success,
    ).toBe(true);
    expect(
      V1CreateUploadIntentRequest.safeParse({
        ...common,
        purpose: "profile_image",
        studentId: "dddddddd-0000-4000-8000-000000000001",
      }).success,
    ).toBe(false);
  });

  test("rejects caller-selected storage and ownership fields", () => {
    for (
      const injected of [
        { path: "another-school/file" },
        { objectKey: "quarantine/attacker" },
        { bucket: "private-school-files" },
        { ownerId: "dddddddd-0000-4000-8000-000000000001" },
        { scanState: "clean" },
      ]
    ) {
      expect(
        V1CreateUploadIntentRequest.safeParse({
          ...common,
          purpose: "profile_image",
          ...injected,
        }).success,
      ).toBe(false);
    }
  });
});

describe("/v1 typed contracts (ARC-011)", () => {
  test("OpenAPI schemas and operations stay aligned with zod contracts", async () => {
    const specUrl = new URL("../openapi/v1.json", import.meta.url);
    const spec = await Bun.file(specUrl).json() as {
      paths: Record<string, {
        get?: { operationId: string };
        post?: {
          operationId: string;
          "x-studafy-idempotency-mode": string;
          responses: Record<string, { headers: Record<string, unknown> }>;
        };
      }>;
      components: {
        schemas: Record<string, { properties: Record<string, unknown> }>;
        headers: Record<string, { schema: { format?: string } }>;
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
    expect(spec.paths["/v1/me"]!.get!.operationId).toBe("getMe");
    expect(spec.paths["/v1/classrooms"]!.get!.operationId).toBe(
      "listClassrooms",
    );
    expect(spec.components.headers.XRequestId!.schema.format).toBe("uuid");
    expect(
      spec.paths["/v1/auth/sign-out"]!.post!.responses["200"]!
        .headers["Cache-Control"],
    )
      .toEqual({ $ref: "#/components/headers/CacheControl" });
    expect(spec.paths["/v1/auth/sign-out"]!.post!["x-studafy-idempotency-mode"])
      .toBe("required");
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

  test("learner assessment questions cannot carry answer guidance", () => {
    const question = {
      id: "11111111-1111-4111-8111-111111111111",
      position: 1,
      prompt: "Name the organelle",
      maximumScore: 2,
    };
    expect(
      V1AssessmentQuestionsResponse.safeParse({
        items: [{ ...question, preferredAnswer: "nucleus" }],
        nextCursor: null,
      }).success,
    ).toBe(false);
    expect(
      V1AssessmentAuthoringQuestionsResponse.parse({
        items: [{ ...question, preferredAnswer: "nucleus" }],
        nextCursor: null,
      }).items[0]?.preferredAnswer,
    ).toBe("nucleus");
  });

  test("every published request body is an allowlist with no additional properties", async () => {
    const specUrl = new URL("../openapi/v1.json", import.meta.url);
    const spec = await Bun.file(specUrl).json() as {
      paths: Record<
        string,
        Record<string, {
          requestBody?: {
            content: { "application/json": { schema: { $ref: string } } };
          };
        }>
      >;
      components: {
        schemas: Record<string, { additionalProperties?: boolean }>;
      };
    };
    for (const pathItem of Object.values(spec.paths)) {
      for (const operation of Object.values(pathItem)) {
        const reference = operation.requestBody?.content["application/json"]
          .schema.$ref;
        if (!reference) continue;
        const name = reference.split("/").at(-1)!;
        expect(spec.components.schemas[name]?.additionalProperties, name).toBe(
          false,
        );
      }
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
          /^(userId|schoolId|role|actorId|tenantId)$/.test(field)
        ),
      }).toEqual({ name, leaked: [] });
    }
  });

  test("V1MeResponse accepts a valid authenticated profile", () => {
    const parsed = V1MeResponse.parse({
      id: "00000000-0000-4000-8000-000000000001",
      displayName: "Rana Haddad",
      memberships: [
        {
          id: "00000000-0000-4000-8000-0000000000aa",
          schoolId: "00000000-0000-4000-8000-0000000000bb",
          schoolName: "Al-Noor International",
          role: "teacher",
          active: true,
        },
      ],
      activeTermId: "00000000-0000-4000-8000-0000000000cc",
    });
    expect(parsed.memberships).toHaveLength(1);
    expect(parsed.memberships[0]!.role).toBe("teacher");
  });

  test("V1MeResponse rejects an unknown role", () => {
    expect(() =>
      V1MeResponse.parse({
        id: "00000000-0000-4000-8000-000000000001",
        displayName: "x",
        memberships: [
          {
            id: "00000000-0000-4000-8000-000000000002",
            schoolId: "00000000-0000-4000-8000-000000000003",
            schoolName: "x",
            role: "admin",
            active: true,
          },
        ],
        activeTermId: null,
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
          studentCount: 6,
          weeklySessions: 3,
          termName: "Term 1",
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
            studentCount: -1,
            weeklySessions: null,
            termName: null,
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

describe("operation ids are checked at compile time", () => {
  test("a known id resolves and an unknown one does not compile", () => {
    expect(v1Route("getStudyPlan").path).toBe("/v1/me/study-plan");
    // @ts-expect-error: not an operation in the catalogue.
    expect(() => v1Route("getStudyPlann")).toThrow();
  });
});

describe("sending a message", () => {
  const id = "00000000-0000-4000-8000-000000000001";

  test("a voice note needs no text", () => {
    expect(
      V1SendMessageRequest.safeParse({
        clientMessageId: id,
        body: "",
        attachmentFileIds: [id],
      }).success,
    ).toBe(true);
  });

  test("a message with neither text nor an attachment is refused", () => {
    expect(
      V1SendMessageRequest.safeParse({ clientMessageId: id, body: "  " })
        .success,
    ).toBe(false);
  });
});

describe("billing: the student plans are accepted", () => {
  test("Plus and Max purchases and approvals validate", () => {
    for (const key of ["studafy_plus", "studafy_max"]) {
      expect(
        V1SubmitPurchaseRequest.safeParse({
          platform: "play_store",
          environment: "development",
          productFeatureKey: key,
          storeProductId: `${key}_monthly`,
          verificationPayload: "opaque",
        }).success,
      ).toBe(true);
      expect(
        V1RequestPurchaseApprovalRequest.safeParse({ featureKey: key }).success,
      )
        .toBe(true);
    }
  });

  test("an entitlement carries its renewal status", () => {
    expect(
      V1EntitlementsResponse.safeParse({
        entitlements: [{
          featureKey: "studafy_max",
          status: "active",
          startsAt: "2026-09-01T00:00:00Z",
          endsAt: "2026-10-01T00:00:00Z",
          beneficiaryStudentId: null,
          renewalStatus: "cancelled",
          platform: "app_store",
          storeProductId: "studafy_max_monthly",
          purchasedByMe: true,
        }],
      }).success,
    ).toBe(true);
  });
});
