import { describe, expect, test } from "bun:test";
import {
  analyzeBytes,
  EICAR_SIGNATURE,
  parseMp4,
  transformBytes,
} from "../src";

// Voice notes. Synthesized, like every other file fixture: a minimal MP4
// with the box structure a phone's recorder writes. The parser checks the
// structure, not the audio, so the leaves carry zeros.

function ascii(text: string): number[] {
  return [...text].map((char) => char.charCodeAt(0));
}

function box(type: string, ...payload: (number[] | Uint8Array)[]): number[] {
  const body = payload.flatMap((part) => [...part]);
  const size = 8 + body.length;
  return [
    (size >>> 24) & 0xff,
    (size >>> 16) & 0xff,
    (size >>> 8) & 0xff,
    size & 0xff,
    ...ascii(type),
    ...body,
  ];
}

const zeros = (count: number) => new Array<number>(count).fill(0);

interface Options {
  brand?: string;
  handler?: string;
  selfContained?: boolean;
  udta?: number[];
  trailing?: number[];
}

function buildM4a(options: Options = {}): Uint8Array {
  const dref = box(
    "dref",
    zeros(4),
    [0, 0, 0, 1],
    box("url ", [0, 0, 0, options.selfContained === false ? 0 : 1]),
  );
  const track = box(
    "trak",
    box("tkhd", zeros(84)),
    box(
      "mdia",
      box("mdhd", zeros(24)),
      box("hdlr", zeros(8), ascii(options.handler ?? "soun"), zeros(13)),
      box(
        "minf",
        box("smhd", zeros(8)),
        box("dinf", dref),
        box(
          "stbl",
          box("stsd", zeros(8)),
          box("stts", zeros(8)),
          box("stsc", zeros(8)),
          box("stsz", zeros(12)),
          box("stco", zeros(8)),
        ),
      ),
    ),
  );
  const moov = box(
    "moov",
    box("mvhd", zeros(100)),
    track,
    ...(options.udta ? [box("udta", options.udta)] : []),
  );
  return Uint8Array.from([
    ...box("ftyp", ascii(options.brand ?? "M4A "), zeros(4), ascii("M4A isom")),
    ...moov,
    ...box("mdat", zeros(64)),
    ...(options.trailing ?? []),
  ]);
}

describe("voice notes (mp4 audio)", () => {
  test("a recorder's M4A is clean", async () => {
    expect(parseMp4(buildM4a()).ok).toBe(true);
    expect(await analyzeBytes(buildM4a(), "audio/mp4")).toEqual({
      verdict: "clean",
    });
  });

  test("a video track is refused, even in an M4A", async () => {
    expect(await analyzeBytes(buildM4a({ handler: "vide" }), "audio/mp4"))
      .toEqual({ verdict: "policy_rejected", errorCode: "not_audio" });
  });

  test("media fetched from somewhere else is refused", async () => {
    expect(
      await analyzeBytes(buildM4a({ selfContained: false }), "audio/mp4"),
    ).toEqual({ verdict: "policy_rejected", errorCode: "external_reference" });
  });

  test("anything after the last box is refused", async () => {
    const result = await analyzeBytes(
      buildM4a({ trailing: ascii("%PDF-1.7 hidden") }),
      "audio/mp4",
    );
    expect(result.verdict).toBe("malformed");
  });

  test("a brand outside the MP4 family is refused", async () => {
    expect(parseMp4(buildM4a({ brand: "qt  " })).ok).toBe(false);
  });

  test("a truncated file is refused", () => {
    const bytes = buildM4a();
    expect(parseMp4(bytes.subarray(0, bytes.length - 10)).ok).toBe(false);
  });

  test("a malware signature hidden in metadata is caught", async () => {
    const result = await analyzeBytes(
      buildM4a({ udta: ascii(EICAR_SIGNATURE) }),
      "audio/mp4",
    );
    expect(result).toEqual({
      verdict: "malicious",
      errorCode: "malware_detected",
    });
  });

  test("metadata is blanked in place, so every offset still holds", () => {
    const bytes = buildM4a({ udta: ascii("GPS 51.5N 0.12W my-phone") });
    const cleaned = transformBytes(bytes, "audio/mp4").bytes!;

    expect(cleaned.length).toBe(bytes.length);
    const text = new TextDecoder().decode(cleaned);
    expect(text).not.toContain("GPS");
    expect(text).not.toContain("udta");
    expect(text).toContain("free");
    // Still a valid voice note, and the same bytes every time.
    expect(parseMp4(cleaned).ok).toBe(true);
    expect(transformBytes(bytes, "audio/mp4").bytes).toEqual(cleaned);
  });
});
