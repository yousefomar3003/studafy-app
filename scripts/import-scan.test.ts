import { describe, expect, test } from "bun:test";
import { extractImports } from "./import-scan";

describe("import scanning for the bounds check", () => {
  test("every statement form is found", () => {
    expect(
      extractImports(`
      import { a } from "pkg-a";
      import type { B } from "@scope/b";
      import * as c from 'node:c';
      import "side-effect";
      export { d } from "./d";
      export type { E } from "pkg-e";
      export * from "pkg-f";
      const g = await import("pkg-g");
      import {
        h,
        i,
      } from "pkg-h";
    `).sort(),
    ).toEqual([
      "./d",
      "@scope/b",
      "node:c",
      "pkg-a",
      "pkg-e",
      "pkg-f",
      "pkg-g",
      "pkg-h",
      "side-effect",
    ]);
  });

  test("'from' in a comment or a string is not an import", () => {
    expect(extractImports(`
      export const Request = z.object({
        /** The app's language, for the "Made from" line. */
        language: z.enum(["en", "ar"]),
      });
      export const words = { from: "Made from", text: "notes" };
      // import nothing from "here"
      const s = 'import "x"';
    `)).toEqual([]);
  });

  test("regular expressions and templates do not hide later imports", () => {
    expect(extractImports(`
      const quote = /["']/g;
      const t = \`a \${"b"} from "c"\`;
      import { z } from "zod";
    `)).toEqual(["zod"]);
  });

  test("import.meta and property names are not imports", () => {
    expect(extractImports(`
      const url = import.meta.url;
      const o = { import: "x" };
    `)).toEqual([]);
  });
});
