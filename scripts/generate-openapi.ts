import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { z } from "zod";
import {
  ProblemDetails,
  ProblemField,
  V1_ROUTE_CATALOGUE,
  V1AuthContextResponse,
  V1AuthDevice,
  V1AuthDeviceListResponse,
  V1AuthDeviceRevokeRequest,
  V1AuthDeviceRevokeResponse,
  V1AuthSignOutRequest,
  V1AuthSignOutResponse,
  V1Classroom,
  V1ClassroomListResponse,
  V1ContextMembership,
  V1DeletionCancelRequest,
  V1DeletionCancelResponse,
  V1DeletionDeletedData,
  V1DeletionImpactMembership,
  V1DeletionImpactResponse,
  V1DeletionRequestRequest,
  V1DeletionRequestResponse,
  V1DeletionRetainedRecords,
  V1IdentityLinkRequest,
  V1IdentityLinkResponse,
  V1IdentityUnlinkRequest,
  V1IdentityUnlinkResponse,
  V1Membership,
  V1MeResponse,
  V1ReauthChallengeRequest,
  V1ReauthChallengeResponse,
  V1ReauthVerifyRequest,
  V1ReauthVerifyResponse,
} from "../packages/contracts/src/index";

const schemas = {
  ProblemField,
  ProblemDetails,
  V1Membership,
  V1MeResponse,
  V1Classroom,
  V1ClassroomListResponse,
  V1ContextMembership,
  V1AuthContextResponse,
  V1AuthDevice,
  V1AuthDeviceListResponse,
  V1AuthDeviceRevokeRequest,
  V1AuthDeviceRevokeResponse,
  V1AuthSignOutRequest,
  V1AuthSignOutResponse,
  V1ReauthChallengeRequest,
  V1ReauthChallengeResponse,
  V1ReauthVerifyRequest,
  V1ReauthVerifyResponse,
  V1IdentityLinkRequest,
  V1IdentityLinkResponse,
  V1IdentityUnlinkRequest,
  V1IdentityUnlinkResponse,
  V1DeletionImpactMembership,
  V1DeletionRetainedRecords,
  V1DeletionDeletedData,
  V1DeletionImpactResponse,
  V1DeletionRequestRequest,
  V1DeletionRequestResponse,
  V1DeletionCancelRequest,
  V1DeletionCancelResponse,
};

const registry = z.registry<{ id: string }>();
for (const [id, schema] of Object.entries(schemas)) {
  schema.register(registry, { id });
}
const generated = z.toJSONSchema(registry, {
  target: "draft-2020-12",
  uri: (id) => `#/components/schemas/${id}`,
}) as { schemas: Record<string, Record<string, unknown>> };
for (const schema of Object.values(generated.schemas)) {
  delete schema["$schema"];
  delete schema["$id"];
}

const paths: Record<string, Record<string, unknown>> = {};
const responseHeaders = {
  "X-Request-ID": { $ref: "#/components/headers/XRequestId" },
  "Cache-Control": { $ref: "#/components/headers/CacheControl" },
  "Content-Security-Policy": {
    $ref: "#/components/headers/ContentSecurityPolicy",
  },
  "Permissions-Policy": { $ref: "#/components/headers/PermissionsPolicy" },
  "Referrer-Policy": { $ref: "#/components/headers/ReferrerPolicy" },
  "X-Content-Type-Options": {
    $ref: "#/components/headers/XContentTypeOptions",
  },
  "X-Frame-Options": { $ref: "#/components/headers/XFrameOptions" },
  "Strict-Transport-Security": {
    $ref: "#/components/headers/StrictTransportSecurity",
  },
  "Idempotency-Replayed": { $ref: "#/components/headers/IdempotencyReplayed" },
};
for (const route of V1_ROUTE_CATALOGUE) {
  const operation: Record<string, unknown> = {
    operationId: route.operationId,
    summary: route.summary,
    security: [{ bearerAuth: [] }],
    "x-studafy-permission": route.permission,
    "x-studafy-idempotency-mode": route.idempotency,
    responses: {
      "200": {
        description: route.summary,
        headers: responseHeaders,
        content: {
          "application/json": {
            schema: { $ref: `#/components/schemas/${route.responseSchema}` },
          },
        },
      },
      default: {
        description: "Problem details",
        headers: responseHeaders,
        content: {
          "application/problem+json": {
            schema: { $ref: "#/components/schemas/ProblemDetails" },
          },
        },
      },
    },
  };
  if (route.requestSchema) {
    operation.requestBody = {
      required: true,
      content: {
        "application/json": {
          schema: { $ref: `#/components/schemas/${route.requestSchema}` },
        },
      },
    };
  }
  if (route.idempotency === "required") {
    operation.parameters = [{
      name: "Idempotency-Key",
      in: "header",
      required: true,
      schema: {
        type: "string",
        minLength: 16,
        maxLength: 128,
        pattern: "^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$",
      },
    }];
  }
  (paths[route.path] ??= {})[route.method] = operation;
}

const spec = {
  openapi: "3.1.0",
  info: {
    title: "Studafy API",
    version: "1.0.0",
    description:
      "Version 1 is additive-only after the API-040 platform contract.",
  },
  "x-studafy-platform": {
    cors: "exact-origin allowlist; disabled when empty",
    requestBodyBytes: 65_536,
    requestTimeoutMilliseconds: 10_000,
    compressedRequestBodies: "rejected",
  },
  paths,
  components: {
    securitySchemes: {
      bearerAuth: { type: "http", scheme: "bearer", bearerFormat: "JWT" },
    },
    headers: {
      XRequestId: {
        description: "Server-generated request identifier.",
        schema: { type: "string", format: "uuid" },
      },
      CacheControl: {
        description: "API responses are not cacheable.",
        schema: { type: "string", const: "no-store" },
      },
      ContentSecurityPolicy: {
        description: "Restrictive API content policy.",
        schema: { type: "string" },
      },
      PermissionsPolicy: {
        description: "Browser capabilities disabled for API responses.",
        schema: { type: "string" },
      },
      ReferrerPolicy: {
        description: "Referrer data is not sent.",
        schema: { type: "string", const: "no-referrer" },
      },
      XContentTypeOptions: {
        description: "MIME sniffing is disabled.",
        schema: { type: "string", const: "nosniff" },
      },
      XFrameOptions: {
        description: "Framing is denied.",
        schema: { type: "string", const: "DENY" },
      },
      StrictTransportSecurity: {
        description: "Emitted by production over HTTPS.",
        schema: {
          type: "string",
          const: "max-age=31536000; includeSubDomains",
        },
      },
      IdempotencyReplayed: {
        description:
          "True only when a completed durable response was replayed.",
        schema: { type: "string", const: "true" },
      },
    },
    schemas: generated.schemas,
  },
};

const output = `${JSON.stringify(spec, null, 2)}\n`;
const outputPath = resolve(
  import.meta.dir,
  "../packages/contracts/openapi/v1.json",
);
if (process.argv.includes("--check")) {
  if (readFileSync(outputPath, "utf8") !== output) {
    console.error("Generated OpenAPI is stale. Run: bun run generate:openapi");
    process.exit(1);
  }
} else {
  writeFileSync(outputPath, output);
  console.log("Generated packages/contracts/openapi/v1.json");
}
