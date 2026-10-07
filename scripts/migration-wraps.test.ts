import { describe, expect, test } from "bun:test";
import { unresolvedWraps } from "./migration-wraps";

const CUTOFF = "m/202609280001_flatten_authorization.sql";
const wrap = (name: string, change = "x") =>
  `alter function private.${name}(text, uuid)\n  rename to ${name}_pre_${change};`;

describe("the rename-and-wrap rule (ADR-0030)", () => {
  test("a wrap after the cutoff with nothing unwinding it is reported", () => {
    expect(
      unresolvedWraps(
        [{ file: "m/202610010001_a.sql", text: wrap("api_q") }],
        CUTOFF,
      ),
    ).toEqual([{ file: "m/202610010001_a.sql", name: "api_q_pre_x" }]);
  });

  test("wraps up to the cutoff are history", () => {
    expect(
      unresolvedWraps(
        [{ file: "m/202609200001_a.sql", text: wrap("api_q") }],
        CUTOFF,
      ),
    ).toEqual([]);
  });

  test("a later rename to a name for what it does unwinds it", () => {
    expect(unresolvedWraps([
      { file: "m/202610010001_a.sql", text: wrap("api_q") },
      {
        file: "m/202610020001_b.sql",
        text:
          "alter function private.api_q_pre_x(text, uuid)\n  rename to api_q_core;",
      },
    ], CUTOFF)).toEqual([]);
  });

  test("a later drop unwinds it", () => {
    expect(unresolvedWraps([
      { file: "m/202610010001_a.sql", text: wrap("authz") },
      {
        file: "m/202610020001_b.sql",
        text: "drop function private.authz_pre_x(text, uuid);",
      },
    ], CUTOFF)).toEqual([]);
  });

  test("renaming it to another history name, or unwinding it earlier, does not count", () => {
    expect(
      unresolvedWraps([
        {
          file: "m/202609300001_early.sql",
          text: "drop function if exists private.api_q_pre_x(text, uuid);",
        },
        { file: "m/202610010001_a.sql", text: wrap("api_q") },
        {
          file: "m/202610020001_b.sql",
          text:
            "alter function private.api_q_pre_x(text, uuid) rename to api_q_before_y;",
        },
      ], CUTOFF).map((w) => w.name),
    ).toEqual(["api_q_pre_x", "api_q_before_y"]);
  });
});
