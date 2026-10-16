import { describe, expect, test } from "bun:test";
import { fileURLToPath } from "node:url";
import { countTable, parseFields } from "./check-listing";

const listing = fileURLToPath(
  new URL("../../docs/store/listing-copy.md", import.meta.url),
);

describe("store listing copy", () => {
  test("every field fits its store limit", async () => {
    const fields = parseFields(await Bun.file(listing).text());
    expect(fields.length).toBeGreaterThanOrEqual(24);
    expect(countTable(fields).ok).toBe(true);
  });

  test("Arabic keywords are counted in bytes", () => {
    const fields = parseFields(
      "<!-- field: k max=10 unit=bytes -->\n```text\nمعلم,طالب\n```",
    );
    // Eight Arabic letters at two bytes each, and a comma.
    expect(countTable(fields)).toMatchObject({ ok: false });
    expect(countTable(fields).table).toContain("| 17 | 10 |");
  });

  test("an optional block is counted with the field it is added to", () => {
    const fields = parseFields(
      "<!-- field: a max=10 -->\n```text\n12345\n```\n" +
        "<!-- field: b max=10 adds-to=a -->\n```text\n1234\n```",
    );
    // 5 + 2 (blank line) + 4.
    expect(countTable(fields).table).toContain("| `a + b` | 11 | 10 |");
  });
});
