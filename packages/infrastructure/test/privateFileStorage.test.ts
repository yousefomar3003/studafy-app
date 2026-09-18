import { describe, expect, test } from "bun:test";
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
});
