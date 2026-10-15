/**
 * Counts every field of docs/store/listing-copy.md against its store limit
 * (launch plan A4) and keeps the table in that file up to date.
 *
 *   bun scripts/store/check-listing.ts          # fail if a limit is broken or the table is stale
 *   bun scripts/store/check-listing.ts --write  # rewrite the table
 *
 * A field is a ```text block preceded by
 *   <!-- field: <id> max=<n> [unit=bytes] [adds-to=<id>] -->
 *
 * Characters are counted as UTF-16 code units, which is what the consoles'
 * own counters use and is never less than the number of letters (Arabic
 * diacritics count as characters). App Store keywords are limited in bytes,
 * so `unit=bytes` counts UTF-8 bytes: an Arabic letter is two. A field with
 * `adds-to` is an optional block appended to another field (after a blank
 * line); the sum must fit that field's limit too.
 */
import { fileURLToPath } from "node:url";

const path = fileURLToPath(
  new URL("../../docs/store/listing-copy.md", import.meta.url),
);
const write = process.argv.includes("--write");

interface Field {
  id: string;
  max: number;
  bytes: boolean;
  addsTo: string | null;
  text: string;
}

export function parseFields(markdown: string): Field[] {
  const pattern =
    /<!-- field: (\S+) max=(\d+)((?: \S+=\S+)*) -->\s*\n```text\n([\s\S]*?)\n```/g;
  const fields: Field[] = [];
  for (const match of markdown.matchAll(pattern)) {
    const options = new Map(
      (match[3] ?? "").trim().split(/\s+/).filter(Boolean).map((option) =>
        option.split("=") as [string, string]
      ),
    );
    fields.push({
      id: match[1]!,
      max: Number(match[2]),
      bytes: options.get("unit") === "bytes",
      addsTo: options.get("adds-to") ?? null,
      text: match[4]!,
    });
  }
  return fields;
}

const measure = (text: string, bytes: boolean) =>
  bytes ? new TextEncoder().encode(text).length : text.length;

export function countTable(fields: Field[]): { table: string; ok: boolean } {
  const byId = new Map(fields.map((field) => [field.id, field]));
  const rows: string[] = [
    "| Field | Count | Limit | Unit | OK |",
    "|---|---:|---:|---|---|",
  ];
  let ok = true;
  const row = (id: string, count: number, max: number, bytes: boolean) => {
    const pass = count <= max;
    ok &&= pass;
    rows.push(
      `| \`${id}\` | ${count} | ${max} | ${
        bytes ? "UTF-8 bytes" : "characters"
      } | ${pass ? "yes" : "**NO**"} |`,
    );
  };
  for (const field of fields) {
    if (field.bytes && field.id.includes("keywords")) {
      if (/,\s|\s,/.test(field.text)) {
        throw new Error(`${field.id}: no spaces around commas`);
      }
    }
    if (field.addsTo) {
      const base = byId.get(field.addsTo);
      if (!base) throw new Error(`${field.id}: no field ${field.addsTo}`);
      const combined = `${base.text}\n\n${field.text}`;
      row(
        `${field.addsTo} + ${field.id}`,
        measure(combined, base.bytes),
        base.max,
        base.bytes,
      );
    } else {
      row(field.id, measure(field.text, field.bytes), field.max, field.bytes);
    }
  }
  return { table: rows.join("\n"), ok };
}

if (import.meta.main) {
  const markdown = await Bun.file(path).text();
  const { table, ok } = countTable(parseFields(markdown));
  const start = "<!-- counts:start -->";
  const end = "<!-- counts:end -->";
  const before = markdown.slice(0, markdown.indexOf(start) + start.length);
  const after = markdown.slice(markdown.indexOf(end));
  const updated = `${before}\n${table}\n${after}`;
  if (write) {
    await Bun.write(path, updated);
    console.log(table);
  } else if (updated !== markdown) {
    console.error(
      "The count table is out of date: bun scripts/store/check-listing.ts --write",
    );
    process.exitCode = 1;
  }
  if (!ok) {
    console.error("A field is over its limit.");
    process.exitCode = 1;
  }
}
