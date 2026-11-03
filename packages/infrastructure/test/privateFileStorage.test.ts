import { describe, expect, test } from "bun:test";
import {
  buildCfb,
  buildDoc,
  buildPpt,
  buildXls,
  buildXlsx,
} from "@studafy/test-support";
import {
  detectMediaType,
  normalizeDisplayName,
} from "../src/privateFileStorage";

describe("FILE-050 storage policy", () => {
  test("normalizes filenames without turning them into object paths", () => {
    expect(normalizeDisplayName("  ../report\u0000.pdf  ")).toBe(
      ".._report_.pdf",
    );
    expect(normalizeDisplayName("／school／photo.png")).toBe(
      "_school_photo.png",
    );
  });

  test("detects only the FILE-050 signature allowlist", () => {
    expect(detectMediaType(new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d])))
      .toBe("application/pdf");
    expect(detectMediaType(new Uint8Array([0xff, 0xd8, 0xff, 0x00])))
      .toBe("image/jpeg");
    expect(detectMediaType(new Uint8Array([0x3c, 0x73, 0x76, 0x67])))
      .toBeNull();
    expect(detectMediaType(new Uint8Array([0x50, 0x4b, 0x03, 0x04])))
      .toBeNull();
  });

  test("detects a workbook by its parts and a CSV only as plain text (DL-077)", () => {
    const encode = (text: string) => new TextEncoder().encode(text);
    expect(detectMediaType(buildXlsx([{ name: "S", rows: [["a"]] }])))
      .toBe(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      );
    expect(detectMediaType(encode("Name,Score\nلينا,18\n"))).toBe("text/csv");
    // Binary bytes, a NUL, or a web page are never detected as CSV, so a
    // file declared as text/csv with such bytes is a type mismatch.
    expect(detectMediaType(new Uint8Array([0x00, 0x01, 0x02, 0xff])))
      .toBeNull();
    expect(detectMediaType(encode("a,b\n\u0000\n"))).toBeNull();
    expect(detectMediaType(encode("<html><script></script></html>")))
      .toBeNull();
    // A PDF is still a PDF, however textual its bytes.
    expect(detectMediaType(encode("%PDF-1.7\n1 0 obj\n"))).toBe(
      "application/pdf",
    );
  });

  test("detects old binary Office files by their main stream (DL-078)", () => {
    expect(detectMediaType(buildDoc())).toBe("application/msword");
    expect(detectMediaType(buildXls())).toBe("application/vnd.ms-excel");
    expect(detectMediaType(buildPpt())).toBe("application/vnd.ms-powerpoint");
    // A compound file that is none of them (an .msg, say) is no type, and
    // neither is a bare signature.
    expect(detectMediaType(buildCfb([{ path: ["__substg1.0"], data: "x" }])))
      .toBeNull();
    expect(
      detectMediaType(
        new Uint8Array([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]),
      ),
    ).toBeNull();
  });
});
