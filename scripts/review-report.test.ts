import { describe, expect, test } from "bun:test";
import { noGrantHelp, parseArgs, UsageError } from "./review-report";

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

describe("review-report without a grant", () => {
  const result = {
    schoolId: "11111111-1111-4111-8111-111111111111",
    schoolHash: "9a0c51e2b7d4f018",
  };

  test("single-reviewer mode: you approve your own single-reviewer grant", () => {
    const help = noGrantHelp(result, true);
    expect(help).toContain(
      `School: ${result.schoolId} (alert hash #9a0c51e2b7d4f018)`,
    );
    expect(help).toContain("Single-reviewer mode is on (DL-063)");
    expect(help).toContain("requiresSecondApprover: false");
    expect(help).toContain("/approve   (you)");
    expect(help).not.toContain("other operator");
  });

  test("otherwise a second operator approves", () => {
    const help = noGrantHelp(result, false);
    expect(help).toContain("have a second operator approve it");
    expect(help).toContain("/approve   (the other operator)");
    expect(help).not.toContain("requiresSecondApprover");
    expect(help).not.toContain("Single-reviewer");
  });
});
