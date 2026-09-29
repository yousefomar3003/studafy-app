import { describe, expect, test } from "bun:test";
import {
  CLASS_CODE_ALPHABET,
  CLASS_CODE_LENGTH,
  formatClassCode,
  generateClassCode,
  hashClassCode,
  normalizeClassCode,
} from "../../src/class-join/code";

/**
 * JOIN-053 class codes. Short by design, so the properties that keep them
 * safe - an unambiguous alphabet, an even spread, a keyed hash - are pinned
 * here rather than left to the integration suite to notice.
 */
describe("class codes", () => {
  test("the alphabet has nothing a child can misread", () => {
    expect(CLASS_CODE_ALPHABET).toHaveLength(32);
    for (const confusable of ["0", "O", "1", "I"]) {
      expect(CLASS_CODE_ALPHABET).not.toContain(confusable);
    }
    expect(new Set(CLASS_CODE_ALPHABET).size).toBe(32);
  });

  test("a fresh code is eight characters from the alphabet", () => {
    for (let i = 0; i < 200; i++) {
      const code = generateClassCode();
      expect(code).toHaveLength(CLASS_CODE_LENGTH);
      expect(normalizeClassCode(code)).toBe(code);
    }
  });

  test("codes are spread across the whole alphabet", () => {
    // Not a statistical test of the RNG; a guard against an off-by-one that
    // quietly never emits some characters and shrinks the search space.
    const seen = new Set<string>();
    for (let i = 0; i < 500; i++) {
      for (const char of generateClassCode()) seen.add(char);
    }
    expect(seen.size).toBe(32);
  });

  test("it is shown as two groups of four", () => {
    expect(formatClassCode("ABCDEFGH")).toBe("ABCD-EFGH");
  });

  test("case, spaces and the dash are forgiven", () => {
    expect(normalizeClassCode("abcd-efgh")).toBe("ABCDEFGH");
    expect(normalizeClassCode(" ab cd ef gh ")).toBe("ABCDEFGH");
    expect(normalizeClassCode("ABCD - EFGH")).toBe("ABCDEFGH");
  });

  test("anything that cannot be a code is refused before it is hashed", () => {
    expect(normalizeClassCode("ABCDEFG")).toBeNull(); // too short
    expect(normalizeClassCode("ABCDEFGHJ")).toBeNull(); // too long
    expect(normalizeClassCode("ABCDEFG0")).toBeNull(); // 0 is not in it
    expect(normalizeClassCode("ABCDEFGO")).toBeNull(); // nor O
    expect(normalizeClassCode("ABCD'EFG")).toBeNull();
    expect(normalizeClassCode("")).toBeNull();
  });

  test("the hash is keyed: the same code under another key differs", async () => {
    const a = await hashClassCode("ABCDEFGH", "k".repeat(32));
    const b = await hashClassCode("ABCDEFGH", "k".repeat(32));
    const c = await hashClassCode("ABCDEFGH", "q".repeat(32));
    expect(a).toBe(b);
    expect(a).not.toBe(c);
    expect(a).toMatch(/^[0-9a-f]{64}$/);
  });

  test("the hash is not the unkeyed digest a table reader could rebuild", async () => {
    const keyed = await hashClassCode("ABCDEFGH", "k".repeat(32));
    const plain = new Uint8Array(
      await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode("ABCDEFGH"),
      ),
    );
    const plainHex = [...plain]
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
    expect(keyed).not.toBe(plainHex);
  });
});
