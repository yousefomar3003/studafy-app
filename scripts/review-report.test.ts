import { describe, expect, test } from "bun:test";
import { parseArgs, UsageError } from "./review-report";

const id = "3f6c0000-0000-4000-8000-0000000000a1";

describe("review-report arguments", () => {
  test("show takes a report id", () => {
    expect(parseArgs(["show", id])).toEqual({ command: "show", reportId: id });
  });

  test("resolve needs a resolution and a real note", () => {
    expect(
      parseArgs([
        "resolve",
        id,
        "--resolution",
        "not_upheld",
        "--note",
        "Not a breach of the rules.",
      ]),
    ).toEqual({
      command: "resolve",
      reportId: id,
      resolution: "not_upheld",
      note: "Not a breach of the rules.",
    });
    expect(() =>
      parseArgs([
        "resolve",
        id,
        "--resolution",
        "deleted",
        "--note",
        "x".repeat(9),
      ])
    ).toThrow(UsageError);
    expect(() =>
      parseArgs(["resolve", id, "--resolution", "upheld", "--note", "ok"])
    ).toThrow(/--note is required/);
  });

  test("anything else is refused", () => {
    expect(() => parseArgs(["escalate", id])).toThrow(UsageError);
    expect(() => parseArgs(["show", "not-a-uuid"])).toThrow(/uuid/);
  });
});
