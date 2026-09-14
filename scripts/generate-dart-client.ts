import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

type Schema = {
  $ref?: string;
  type?: string | string[];
  anyOf?: Schema[];
  items?: Schema;
  properties?: Record<string, Schema>;
  required?: string[];
};

type Operation = {
  operationId: string;
  "x-studafy-idempotency-mode"?: "none" | "required" | "forbidden";
  requestBody?: {
    required?: boolean;
    content: { "application/json": { schema: Schema } };
  };
  responses: Record<
    string,
    { content?: { "application/json"?: { schema: Schema } } }
  >;
};

type OpenApi = {
  paths: Record<string, { get?: Operation; post?: Operation }>;
  components: { schemas: Record<string, Schema> };
};

/** HTTP methods the generator emits, in the order they appear on a path. */
const METHODS = ["get", "post"] as const;
type Method = (typeof METHODS)[number];

const root = resolve(import.meta.dir, "..");
const specPath = resolve(root, "packages/contracts/openapi/v1.json");
const outputPath = resolve(
  root,
  "lib/data/contracts/v1_client.generated.dart",
);
const spec = JSON.parse(readFileSync(specPath, "utf8")) as OpenApi;

function dartName(value: string): string {
  return value.replace(
    /_([a-z])/g,
    (_, letter: string) => letter.toUpperCase(),
  );
}

function referencedName(schema: Schema): string | null {
  return effectiveSchema(schema).$ref?.split("/").at(-1) ?? null;
}

function isNullable(schema: Schema): boolean {
  return (Array.isArray(schema.type) && schema.type.includes("null")) ||
    (schema.anyOf?.some((entry) => entry.type === "null") ?? false);
}

function effectiveSchema(schema: Schema): Schema {
  return schema.anyOf?.find((entry) => entry.type !== "null") ?? schema;
}

function dartType(schema: Schema): string {
  const reference = referencedName(schema);
  const effective = effectiveSchema(schema);
  let base: string;
  if (reference) {
    base = `${reference}Dto`;
  } else {
    const type = Array.isArray(effective.type)
      ? effective.type.find((entry) => entry !== "null")
      : effective.type;
    switch (type) {
      case "string":
        base = "String";
        break;
      case "integer":
        base = "int";
        break;
      case "number":
        base = "num";
        break;
      case "boolean":
        base = "bool";
        break;
      case "array":
        if (!effective.items) throw new Error("Array schema is missing items");
        base = `List<${dartType(effective.items).replace(/\?$/, "")}>`;
        break;
      default:
        throw new Error(`Unsupported OpenAPI schema type: ${String(type)}`);
    }
  }
  return isNullable(schema) ? `${base}?` : base;
}

function propertyType(schema: Schema, required: boolean): string {
  const type = dartType(schema);
  return required || type.endsWith("?") ? type : `${type}?`;
}

function parseExpression(
  schema: Schema,
  wireName: string,
  required: boolean,
): string {
  const reference = referencedName(schema);
  if (reference) {
    const parsed =
      `${reference}Dto.fromJson(json['${wireName}'] as Map<String, dynamic>)`;
    return required ? parsed : `json['${wireName}'] == null ? null : ${parsed}`;
  }
  const effective = effectiveSchema(schema);
  const type = Array.isArray(effective.type)
    ? effective.type.find((entry) => entry !== "null")
    : effective.type;
  if (type === "array") {
    if (!effective.items) throw new Error("Array schema is missing items");
    const itemReference = referencedName(effective.items);
    if (itemReference) {
      const parsed = "[for (final item in json['" + wireName +
        "'] as List<dynamic>) " + itemReference +
        "Dto.fromJson(item as Map<String, dynamic>)]";
      return required
        ? parsed
        : `json['${wireName}'] == null ? null : ${parsed}`;
    }
    const parsed = `(json['${wireName}'] as List<dynamic>).cast<${
      dartType(effective.items).replace(/\?$/, "")
    }>()`;
    return required ? parsed : `json['${wireName}'] == null ? null : ${parsed}`;
  }
  return `json['${wireName}'] as ${propertyType(schema, required)}`;
}

function serializeExpression(schema: Schema, propertyName: string): string {
  if (referencedName(schema)) return `${propertyName}.toJson()`;
  const type = Array.isArray(schema.type)
    ? schema.type.find((entry) => entry !== "null")
    : schema.type;
  if (type === "array" && referencedName(schema.items ?? {})) {
    return `[for (final item in ${propertyName}) item.toJson()]`;
  }
  return propertyName;
}

function renderModel(name: string, schema: Schema): string {
  const properties = Object.entries(schema.properties ?? {});
  if (properties.length === 0) {
    return `class ${name}Dto {
  const ${name}Dto();

  factory ${name}Dto.fromJson(Map<String, dynamic> json) => const ${name}Dto();

  Map<String, Object?> toJson() => const <String, Object?>{};
}`;
  }
  const required = new Set(schema.required ?? []);
  const constructor = properties.map(([wireName]) => {
    const keyword = required.has(wireName) ? "required " : "";
    return `    ${keyword}this.${dartName(wireName)},`;
  }).join("\n");
  const fields = properties.map(([wireName, property]) =>
    `  final ${propertyType(property, required.has(wireName))} ${
      dartName(wireName)
    };`
  ).join("\n");
  const parser = properties.map(([wireName, property]) =>
    `      ${dartName(wireName)}: ${
      parseExpression(property, wireName, required.has(wireName))
    },`
  ).join("\n");
  const serializer = properties.map(([wireName, property]) => {
    const propertyName = dartName(wireName);
    const isRequired = required.has(wireName);
    return `    ${
      isRequired ? "" : `if (${propertyName} != null) `
    }'${wireName}': ${
      serializeExpression(
        property,
        isRequired ? propertyName : `${propertyName}!`,
      )
    },`;
  }).join("\n");

  return `class ${name}Dto {
  const ${name}Dto({
${constructor}
  });

  factory ${name}Dto.fromJson(Map<String, dynamic> json) => ${name}Dto(
${parser}
  );

${fields}

  Map<String, Object?> toJson() => {
${serializer}
  };
}`;
}

function renderOperation(
  path: string,
  method: Method,
  operation: Operation,
): string {
  const responseSchema = operation.responses["200"]?.content
    ?.["application/json"]
    ?.schema;
  const responseName = responseSchema && referencedName(responseSchema);
  if (!responseName) {
    throw new Error(
      `${operation.operationId} must have a referenced 200 response`,
    );
  }
  if (method === "get") {
    return `  Future<${responseName}Dto> ${operation.operationId}() async =>
      ${responseName}Dto.fromJson(await _transport.get('${path}'));`;
  }

  const requestSchema = operation.requestBody?.content["application/json"]
    .schema;
  const requestName = requestSchema && referencedName(requestSchema);
  const idempotent = operation["x-studafy-idempotency-mode"] === "required";
  const optionalKey = idempotent ? "{String? idempotencyKey}" : "";
  const postOptions = idempotent
    ? "idempotencyKey: idempotencyKey, requiresIdempotency: true"
    : "";
  if (requestSchema && !requestName) {
    throw new Error(
      `${operation.operationId} request body must reference a schema`,
    );
  }
  // A command with no body still posts an empty object, so the transport has
  // one shape to serialize and servers see a consistent content type.
  if (!requestName) {
    return `  Future<${responseName}Dto> ${operation.operationId}(${optionalKey}) async =>
      ${responseName}Dto.fromJson(
        await _transport.post('${path}', const <String, Object?>{}, ${postOptions}),
      );`;
  }
  return `  Future<${responseName}Dto> ${operation.operationId}(
    ${requestName}Dto request, ${optionalKey}
  ) async =>
      ${responseName}Dto.fromJson(
        await _transport.post('${path}', request.toJson(), ${postOptions}),
      );`;
}

const models = Object.entries(spec.components.schemas)
  .map(([name, schema]) => renderModel(name, schema))
  .join("\n\n");
const operations = Object.entries(spec.paths)
  .flatMap(([path, pathItem]) =>
    METHODS.flatMap((method) => {
      const operation = pathItem[method];
      return operation ? [renderOperation(path, method, operation)] : [];
    })
  )
  .join("\n\n");

const unformatted = `// GENERATED CODE — DO NOT EDIT.
// Source: packages/contracts/openapi/v1.json
// Regenerate: bun run generate:dart-client

abstract interface class V1JsonTransport {
  Future<Map<String, dynamic>> get(String path);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  });
}

class V1ApiClient {
  const V1ApiClient(this._transport);

  final V1JsonTransport _transport;

${operations}
}

${models}
`;

const formatDirectory = mkdtempSync(join(tmpdir(), "studafy-dart-codegen-"));
const formatPath = join(formatDirectory, "v1_client.generated.dart");
let generated: string;
try {
  writeFileSync(formatPath, unformatted);
  const formatter = spawnSync("dart", ["format", formatPath], {
    encoding: "utf8",
  });
  if (formatter.status !== 0) {
    throw new Error(`dart format failed: ${formatter.stderr.trim()}`);
  }
  generated = readFileSync(formatPath, "utf8");
} finally {
  rmSync(formatDirectory, { recursive: true, force: true });
}

if (process.argv.includes("--check")) {
  const existing = readFileSync(outputPath, "utf8");
  if (existing !== generated) {
    console.error(
      "Generated Dart client is stale. Run: bun run generate:dart-client",
    );
    process.exit(1);
  }
} else {
  writeFileSync(outputPath, generated);
  console.log("Generated lib/data/contracts/v1_client.generated.dart");
}
