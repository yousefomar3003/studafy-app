import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { z } from "zod";
import { V1_ROUTE_CATALOGUE } from "../packages/contracts/src/index";
// A single namespace import of the v1 barrel, not a hand-maintained list:
// every schema packages/contracts/src/v1/index.ts re-exports (however it
// re-exports it - named or `export *`) is registered automatically, so a
// new v1/<module>.ts schema can never again go undefined in the generated
// spec just because this file forgot to list it.
import * as AllV1 from "../packages/contracts/src/v1";

const registry = z.registry<{ id: string }>();
for (const [id, value] of Object.entries(AllV1)) {
  if (value instanceof z.ZodType) value.register(registry, { id });
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
  const successStatus = String(route.successStatus ?? 200);
  const operation: Record<string, unknown> = {
    operationId: route.operationId,
    summary: route.summary,
    security: [{ bearerAuth: [] }],
    "x-studafy-permission": route.permission,
    "x-studafy-idempotency-mode": route.idempotency,
    responses: {
      [successStatus]: {
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
  const parameters: Record<string, unknown>[] = [];
  if (route.params && "shape" in route.params) {
    for (const name of Object.keys(route.params.shape)) {
      parameters.push({
        name,
        in: "path",
        required: true,
        schema: { type: "string", format: "uuid" },
      });
    }
  }
  if (route.query && "shape" in route.query) {
    const shape = route.query.shape as Record<string, z.ZodType>;
    for (const [name, schema] of Object.entries(shape)) {
      const generatedQuery = z.toJSONSchema(schema, {
        target: "draft-2020-12",
      }) as Record<string, unknown>;
      delete generatedQuery["$schema"];
      parameters.push({
        name,
        in: "query",
        required: false,
        schema: generatedQuery,
      });
    }
  }
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
    parameters.push({
      name: "Idempotency-Key",
      in: "header",
      required: true,
      schema: {
        type: "string",
        minLength: 16,
        maxLength: 128,
        pattern: "^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$",
      },
    });
  }
  if (parameters.length > 0) operation.parameters = parameters;
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
