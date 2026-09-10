import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

type Schema = {
  $ref?: string;
  type?: string | string[];
  items?: Schema;
  properties?: Record<string, Schema>;
  required?: string[];
};

type OpenApi = {
  paths: Record<
    string,
    {
      get?: {
        operationId: string;
        responses: Record<
          string,
          { content?: { "application/json"?: { schema: Schema } } }
        >;
      };
    }
  >;
  components: { schemas: Record<string, Schema> };
};

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
  return schema.$ref?.split("/").at(-1) ?? null;
}

function isNullable(schema: Schema): boolean {
  return Array.isArray(schema.type) && schema.type.includes("null");
}

function dartType(schema: Schema): string {
  const reference = referencedName(schema);
  let base: string;
  if (reference) {
    base = `${reference}Dto`;
  } else {
    const type = Array.isArray(schema.type)
      ? schema.type.find((entry) => entry !== "null")
      : schema.type;
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
        if (!schema.items) throw new Error("Array schema is missing items");
        base = `List<${dartType(schema.items).replace(/\?$/, "")}>`;
        break;
      default:
        throw new Error(`Unsupported OpenAPI schema type: ${String(type)}`);
    }
  }
  return isNullable(schema) ? `${base}?` : base;
}

function parseExpression(schema: Schema, wireName: string): string {
  const reference = referencedName(schema);
  if (reference) {
    return `${reference}Dto.fromJson(json['${wireName}'] as Map<String, dynamic>)`;
  }
  const type = Array.isArray(schema.type)
    ? schema.type.find((entry) => entry !== "null")
    : schema.type;
  if (type === "array") {
    if (!schema.items) throw new Error("Array schema is missing items");
    const itemReference = referencedName(schema.items);
    if (itemReference) {
      return "[for (final item in json['" + wireName +
        "'] as List<dynamic>) " + itemReference +
        "Dto.fromJson(item as Map<String, dynamic>)]";
    }
    return `(json['${wireName}'] as List<dynamic>).cast<${
      dartType(schema.items).replace(/\?$/, "")
    }>()`;
  }
  return `json['${wireName}'] as ${dartType(schema)}`;
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
  const required = new Set(schema.required ?? []);
  const constructor = properties.map(([wireName]) => {
    const keyword = required.has(wireName) ? "required " : "";
    return `    ${keyword}this.${dartName(wireName)},`;
  }).join("\n");
  const fields = properties.map(([wireName, property]) =>
    `  final ${dartType(property)} ${dartName(wireName)};`
  ).join("\n");
  const parser = properties.map(([wireName, property]) =>
    `      ${dartName(wireName)}: ${parseExpression(property, wireName)},`
  ).join("\n");
  const serializer = properties.map(([wireName, property]) =>
    `    '${wireName}': ${serializeExpression(property, dartName(wireName))},`
  ).join("\n");

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
  operation: NonNullable<OpenApi["paths"][string]["get"]>,
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
  return `  Future<${responseName}Dto> ${operation.operationId}() async =>
      ${responseName}Dto.fromJson(await _transport.get('${path}'));`;
}

const models = Object.entries(spec.components.schemas)
  .map(([name, schema]) => renderModel(name, schema))
  .join("\n\n");
const operations = Object.entries(spec.paths)
  .flatMap(([path, pathItem]) =>
    pathItem.get ? [renderOperation(path, pathItem.get)] : []
  )
  .join("\n\n");

const unformatted = `// GENERATED CODE — DO NOT EDIT.
// Source: packages/contracts/openapi/v1.json
// Regenerate: bun run generate:dart-client

abstract interface class V1JsonTransport {
  Future<Map<String, dynamic>> get(String path);
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
