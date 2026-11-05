import { describe, expect, test } from "bun:test";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { ar } from "../src/i18n/ar";
import { en } from "../src/i18n/en";

type Leaf = { path: string; value: string };

function leaves(value: unknown, path = ""): Leaf[] {
  if (typeof value === "string") return [{ path, value }];
  if (Array.isArray(value)) {
    return value.flatMap((item, index) => leaves(item, `${path}[${index}]`));
  }
  if (value && typeof value === "object") {
    return Object.entries(value).flatMap(([key, item]) =>
      leaves(item, path ? `${path}.${key}` : key)
    );
  }
  return [];
}

/** Values that name things in code, not words a reader sees. */
const CODE_KEYS = /\.(key|icon|screen|screen2)$/;

describe("site copy", () => {
  const english = leaves(en);
  const arabic = leaves(ar);

  test("English and Arabic have the same entries, in the same order", () => {
    expect(arabic.map((leaf) => leaf.path)).toEqual(
      english.map((leaf) => leaf.path),
    );
  });

  test("no entry is empty", () => {
    for (const leaf of [...english, ...arabic]) {
      expect(leaf.value.trim().length, leaf.path).toBeGreaterThan(0);
    }
  });

  test("code names (icons, screens, role keys) match between languages", () => {
    const codeEn = english.filter((leaf) => CODE_KEYS.test(leaf.path));
    const codeAr = arabic.filter((leaf) => CODE_KEYS.test(leaf.path));
    expect(codeAr).toEqual(codeEn);
  });

  test("every screenshot named in the copy exists in both languages", () => {
    const screens = english.filter((leaf) => /\.screen2?$/.test(leaf.path)).map(
      (leaf) => leaf.value,
    );
    for (const lang of ["en", "ar"]) {
      for (const screen of screens) {
        const file = join(
          import.meta.dir,
          "..",
          "public",
          "screens",
          lang,
          `${screen}.webp`,
        );
        expect(existsSync(file), file).toBe(true);
      }
    }
  });

  test("Arabic follows the app's glossary", () => {
    const text = arabic.map((leaf) => leaf.value).join("\n");
    // A class is صف; فصل means only a term or a chapter.
    expect(text).not.toMatch(/فصل|فصول/);
    expect(text).not.toMatch(/ستدفاي/);
    // Plan names stay in Latin letters.
    expect(text).not.toMatch(/العائلة\+/);
  });

  test("the copy makes no claims the store listing forbids", () => {
    for (const leaf of [...english, ...arabic]) {
      expect(leaf.value, leaf.path).not.toMatch(
        /\bbest\b|#1|\$|€|£|JOD|دينار/i,
      );
    }
  });
});
