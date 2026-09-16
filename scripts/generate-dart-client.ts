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
  enum?: string[];
};

type Operation = {
  operationId: string;
  "x-studafy-idempotency-mode"?: "none" | "required" | "forbidden";
  parameters?: Array<{
    name: string;
    in: "path" | "query" | "header";
    required?: boolean;
    schema: Schema;
  }>;
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

/**
 * True when a named component schema is a bare string enum (a Zod `z.enum()`
 * registered at the top level, e.g. V1ReauthPurpose) rather than a structured
 * object. These still surface as `$ref`s wherever they're used, exactly like
 * an object component, but have no `properties` and must not go through the
 * object-DTO code path - there is nothing to construct, and the wire value
 * already is the Dart-usable value.
 */
function isEnumComponent(name: string): boolean {
  const target = spec.components.schemas[name];
  return target !== undefined && Array.isArray(target.enum) &&
    target.properties === undefined;
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
    base = isEnumComponent(reference) ? "String" : `${reference}Dto`;
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
      case "object":
        // Only a free-form record (z.record()) reaches this branch: every
        // structured object schema is registered as a named component (see
        // generate-openapi.ts) and resolves through the `reference` branch
        // above instead. A record's own field types aren't representable in
        // the generated client's static types, so it maps to a raw map.
        base = "Map<String, dynamic>";
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
  if (reference && !isEnumComponent(reference)) {
    const parsed =
      `${reference}Dto.fromJson(json['${wireName}'] as Map<String, dynamic>)`;
    return required && !isNullable(schema)
      ? parsed
      : `json['${wireName}'] == null ? null : ${parsed}`;
  }
  const effective = effectiveSchema(schema);
  const type = Array.isArray(effective.type)
    ? effective.type.find((entry) => entry !== "null")
    : effective.type;
  if (type === "array") {
    if (!effective.items) throw new Error("Array schema is missing items");
    const itemReference = referencedName(effective.items);
    if (itemReference && !isEnumComponent(itemReference)) {
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

/** True when serialization is the bare property value, so an optional field
 * can use a Dart null-aware element instead of `if (x != null) 'k': x!`,
 * which the use_null_aware_elements lint rejects in generated code. */
function isBareValue(schema: Schema): boolean {
  const reference = referencedName(schema);
  if (reference && !isEnumComponent(reference)) return false;
  const effective = effectiveSchema(schema);
  const type = Array.isArray(effective.type)
    ? effective.type.find((entry) => entry !== "null")
    : effective.type;
  if (type === "array") {
    const itemReference = referencedName(effective.items ?? {});
    return !itemReference || isEnumComponent(itemReference);
  }
  return true;
}

function serializeExpression(
  schema: Schema,
  propertyName: string,
  knownNonNull: boolean,
): string {
  const reference = referencedName(schema);
  if (reference && !isEnumComponent(reference)) {
    return knownNonNull
      ? `${propertyName}.toJson()`
      : `${propertyName}?.toJson()`;
  }
  const type = Array.isArray(schema.type)
    ? schema.type.find((entry) => entry !== "null")
    : schema.type;
  const itemReference = referencedName(schema.items ?? {});
  if (type === "array" && itemReference && !isEnumComponent(itemReference)) {
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
    if (!isRequired && isBareValue(property)) {
      return `    '${wireName}': ?${propertyName},`;
    }
    return `    ${
      isRequired ? "" : `if (${propertyName} != null) `
    }'${wireName}': ${
      serializeExpression(
        property,
        isRequired ? propertyName : `${propertyName}!`,
        !isRequired || !isNullable(property),
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
  const success = Object.entries(operation.responses).find(([status]) =>
    /^2\d\d$/.test(status)
  )?.[1];
  const responseSchema = success?.content?.["application/json"]?.schema;
  const responseName = responseSchema && referencedName(responseSchema);
  if (!responseName) {
    throw new Error(
      `${operation.operationId} must have a referenced success response`,
    );
  }
  const allParams = (operation.parameters ?? []).filter((entry) =>
    entry.in === "path" || entry.in === "query"
  );
  const pathNames = new Set(
    allParams.filter((entry) => entry.in === "path").map((entry) => entry.name),
  );
  const apiParams = allParams.filter((entry) =>
    entry.in === "path" || !pathNames.has(entry.name)
  );
  const named = apiParams.map((entry) => {
    const rawType = effectiveSchema(entry.schema).type;
    const base = rawType === "integer" ? "int" : "String";
    return `${entry.required ? "required " : ""}${base}${
      entry.required ? "" : "?"
    } ${dartName(entry.name)}`;
  });
  const pathValues = apiParams.filter((entry) => entry.in === "path")
    .map((entry) => `'${entry.name}': ${dartName(entry.name)}`).join(", ");
  const queryValues = apiParams.filter((entry) => entry.in === "query")
    .map((entry) => `'${entry.name}': ${dartName(entry.name)}`).join(", ");
  const resolvedPath = `_v1Path('${path}', {${pathValues}}, {${queryValues}})`;
  if (method === "get") {
    const argumentsText = named.length > 0 ? `({${named.join(", ")}})` : "()";
    return `  Future<${responseName}Dto> ${operation.operationId}${argumentsText} async =>
      ${responseName}Dto.fromJson(await _transport.get(${resolvedPath}));`;
  }

  const requestSchema = operation.requestBody?.content["application/json"]
    .schema;
  const requestName = requestSchema && referencedName(requestSchema);
  const idempotent = operation["x-studafy-idempotency-mode"] === "required";
  if (idempotent) named.push("String? idempotencyKey");
  const optionalKey = named.length > 0 ? `{${named.join(", ")}}` : "";
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
        await _transport.post(${resolvedPath}, const <String, Object?>{}, ${postOptions}),
      );`;
  }
  return `  Future<${responseName}Dto> ${operation.operationId}(
    ${requestName}Dto request, ${optionalKey}
  ) async =>
      ${responseName}Dto.fromJson(
        await _transport.post(${resolvedPath}, request.toJson(), ${postOptions}),
      );`;
}

const models = Object.entries(spec.components.schemas)
  .filter(([name]) => !isEnumComponent(name))
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

String _v1Path(
  String template,
  Map<String, Object?> pathValues,
  Map<String, Object?> queryValues,
) {
  var value = template;
  for (final entry in pathValues.entries) {
    value = value.replaceAll(
      '{\${entry.key}}',
      Uri.encodeComponent(entry.value.toString()),
    );
  }
  final query = <String, String>{
    for (final entry in queryValues.entries)
      if (entry.value != null) entry.key: entry.value.toString(),
  };
  return query.isEmpty
      ? value
      : Uri.parse(value).replace(queryParameters: query).toString();
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
