import { describe, expect, test } from "bun:test";
import {
  biffBoundSheet,
  biffRecord,
  buildCfb,
  buildCfbDetailed,
  buildDoc,
  buildPpt,
  buildXls,
  cfbSectorOffset,
  pptRecord,
  setCfbFatEntry,
  wordDocumentStream,
} from "@studafy/test-support";
import {
  analyzeBytes,
  detectCfbMediaType,
  DOC_MEDIA_TYPE,
  DOCX_MEDIA_TYPE,
  EICAR_SIGNATURE,
  isLegacyOfficeType,
  LEGACY_OFFICE_OOXML,
  parseCfb,
  PPT_MEDIA_TYPE,
  readCfbDirectory,
  XLS_MEDIA_TYPE,
} from "../src";

/**
 * Old binary Office files (DL-078): .doc, .xls and .ppt are compound files.
 * The scan reads their directory under caps and refuses macros, embedded
 * objects, links to other files and passwords, as it does for OOXML.
 */
describe("compound file directory", () => {
  test("reads streams from the mini stream and from regular sectors", () => {
    const big = new Uint8Array(9000).map((_, i) => i % 251);
    const file = buildCfb([
      { path: ["small"], data: "a small stream" },
      { path: ["big"], data: big },
      { path: ["folder", "inner"], data: "nested" },
      { path: ["empty"], data: new Uint8Array() },
    ]);
    const directory = readCfbDirectory(file);
    if (!directory.ok) throw new Error(directory.reason);
    const byName = new Map(
      directory.entries.map((e) => [e.path.join("/"), e]),
    );
    const text = (name: string) =>
      new TextDecoder().decode(directory.read(byName.get(name)!));
    expect(text("small")).toBe("a small stream");
    expect(text("folder/inner")).toBe("nested");
    expect(directory.read(byName.get("big")!)).toEqual(big);
    expect(byName.get("folder")!.type).toBe("storage");
    expect(byName.get("empty")!.size).toBe(0);
  });

  test("the type comes from the one main stream", () => {
    expect(detectCfbMediaType(buildDoc())).toBe(DOC_MEDIA_TYPE);
    expect(detectCfbMediaType(buildXls())).toBe(XLS_MEDIA_TYPE);
    expect(detectCfbMediaType(buildXls({ streamName: "Book" }))).toBe(
      XLS_MEDIA_TYPE,
    );
    expect(detectCfbMediaType(buildPpt())).toBe(PPT_MEDIA_TYPE);
    // Two main streams, or none, is no type at all.
    expect(
      detectCfbMediaType(buildCfb([
        { path: ["WordDocument"], data: wordDocumentStream() },
        { path: ["Workbook"], data: "x" },
      ])),
    ).toBeNull();
    expect(detectCfbMediaType(buildCfb([{ path: ["Other"], data: "x" }])))
      .toBeNull();
    // A Workbook inside a Word file's object storage is not the main stream.
    expect(
      detectCfbMediaType(buildDoc({
        extra: [{ path: ["ObjectPool", "_1", "Workbook"], data: "x" }],
      })),
    ).toBe(DOC_MEDIA_TYPE);
  });

  test("legacy types map to the OOXML format they are read as", () => {
    expect(LEGACY_OFFICE_OOXML[DOC_MEDIA_TYPE]).toBe(DOCX_MEDIA_TYPE);
    expect(isLegacyOfficeType(PPT_MEDIA_TYPE)).toBe(true);
    expect(isLegacyOfficeType(DOCX_MEDIA_TYPE)).toBe(false);
    expect(isLegacyOfficeType(null)).toBe(false);
    expect(isLegacyOfficeType("toString")).toBe(false);
  });
});

describe("plain files are clean", () => {
  test("doc, xls and ppt", async () => {
    expect(await analyzeBytes(buildDoc(), DOC_MEDIA_TYPE)).toEqual({
      verdict: "clean",
    });
    expect(await analyzeBytes(buildXls(), XLS_MEDIA_TYPE)).toEqual({
      verdict: "clean",
    });
    expect(
      await analyzeBytes(buildXls({ large: true }), XLS_MEDIA_TYPE),
    ).toEqual({ verdict: "clean" });
    expect(await analyzeBytes(buildPpt(), PPT_MEDIA_TYPE)).toEqual({
      verdict: "clean",
    });
    expect(parseCfb(buildDoc(), "doc")).toMatchObject({
      ok: true,
      kind: "doc",
    });
  });

  test("a declared type that does not match the main stream is malformed", async () => {
    expect(await analyzeBytes(buildDoc(), XLS_MEDIA_TYPE)).toEqual({
      verdict: "malformed",
      errorCode: "malformed_file",
    });
    expect(parseCfb(buildPpt(), "doc")).toEqual({
      ok: false,
      reason: "malformed",
    });
  });

  test("a Word stream without the FIB signature is malformed", () => {
    expect(
      parseCfb(
        buildDoc({ word: wordDocumentStream({ ident: 0x1234 }) }),
        "doc",
      ),
    )
      .toEqual({ ok: false, reason: "malformed" });
    expect(
      parseCfb(buildDoc({ word: wordDocumentStream({ ident: 0xa5dc }) }), "doc")
        .ok,
    ).toBe(true);
  });
});

describe("macros and active content are refused", () => {
  const refused = {
    verdict: "policy_rejected",
    errorCode: "active_content",
  } as const;

  test("Word and Excel VBA projects", async () => {
    expect(
      await analyzeBytes(
        buildDoc({ extra: [{ path: ["Macros", "VBA", "dir"], data: "x" }] }),
        DOC_MEDIA_TYPE,
      ),
    ).toEqual(refused);
    expect(
      await analyzeBytes(
        buildXls({
          extra: [{ path: ["_VBA_PROJECT_CUR", "PROJECT"], data: "x" }],
        }),
        XLS_MEDIA_TYPE,
      ),
    ).toEqual(refused);
    expect(
      await analyzeBytes(
        buildDoc({ extra: [{ path: ["_VBA_PROJECT"], data: "x" }] }),
        DOC_MEDIA_TYPE,
      ),
    ).toEqual(refused);
  });

  test("Excel 4.0 macro sheets, VBA module sheets and ActiveX controls", async () => {
    for (const sheetType of [0x01, 0x06]) {
      expect(
        await analyzeBytes(
          buildXls({
            records: [biffBoundSheet("Sheet1"), biffBoundSheet("M", sheetType)],
          }),
          XLS_MEDIA_TYPE,
        ),
      ).toEqual(refused);
    }
    expect(
      await analyzeBytes(
        buildXls({ extra: [{ path: ["Ctls"], data: "x" }] }),
        XLS_MEDIA_TYPE,
      ),
    ).toEqual(refused);
    // A chart sheet is not code.
    expect(
      await analyzeBytes(
        buildXls({ records: [biffBoundSheet("Chart", 0x02)] }),
        XLS_MEDIA_TYPE,
      ),
    ).toEqual({ verdict: "clean" });
  });

  test("a presentation's VBA and ActiveX records, nested or not", async () => {
    for (const type of [0x03ff, 0x0400, 0x0fee]) {
      const nested = pptRecord(0x03e8, [
        pptRecord(0x0409, [pptRecord(type, new Uint8Array(4))]),
      ]);
      expect(
        await analyzeBytes(buildPpt({ records: [nested] }), PPT_MEDIA_TYPE),
      ).toEqual(refused);
    }
  });
});

describe("embedded objects and links are refused", () => {
  test("Word ObjectPool with an object, Excel MBD storages, OLE packages", async () => {
    const embedded = {
      verdict: "policy_rejected",
      errorCode: "embedded_file",
    } as const;
    expect(
      await analyzeBytes(
        buildDoc({
          extra: [{
            path: ["ObjectPool", "_1234", "\u0001CompObj"],
            data: "x",
          }],
        }),
        DOC_MEDIA_TYPE,
      ),
    ).toEqual(embedded);
    expect(
      await analyzeBytes(
        buildXls({ extra: [{ path: ["MBD0012AB34", "Contents"], data: "x" }] }),
        XLS_MEDIA_TYPE,
      ),
    ).toEqual(embedded);
    expect(
      await analyzeBytes(
        buildPpt({ extra: [{ path: ["\u0001Ole10Native"], data: "x" }] }),
        PPT_MEDIA_TYPE,
      ),
    ).toEqual(embedded);
    for (const type of [0x0fcc, 0x1011]) {
      expect(
        await analyzeBytes(
          buildPpt({ records: [pptRecord(type, new Uint8Array(12))] }),
          PPT_MEDIA_TYPE,
        ),
      ).toEqual(embedded);
    }
  });

  test("other workbooks, data connections, web queries, linked objects", async () => {
    const external = {
      verdict: "policy_rejected",
      errorCode: "external_reference",
    } as const;
    // SUPBOOK naming another workbook; the self-reference is fine.
    expect(
      await analyzeBytes(
        buildXls({
          records: [
            biffBoundSheet("Sheet1"),
            biffRecord(0x01ae, [1, 0, 5, 0, 0, 0x41]),
          ],
        }),
        XLS_MEDIA_TYPE,
      ),
    ).toEqual(external);
    expect(
      await analyzeBytes(
        buildXls({
          records: [biffBoundSheet("Sheet1"), biffRecord(0x01ae, [1, 0, 1, 4])],
        }),
        XLS_MEDIA_TYPE,
      ),
    ).toEqual({ verdict: "clean" });
    for (const type of [0x01ad, 0x0876]) {
      expect(
        await analyzeBytes(
          buildXls({ records: [biffBoundSheet("Sheet1"), biffRecord(type)] }),
          XLS_MEDIA_TYPE,
        ),
      ).toEqual(external);
    }
    expect(
      await analyzeBytes(
        buildPpt({ records: [pptRecord(0x0fce, new Uint8Array(8))] }),
        PPT_MEDIA_TYPE,
      ),
    ).toEqual(external);
  });
});

describe("passwords are refused", () => {
  const encrypted = {
    verdict: "policy_rejected",
    errorCode: "encrypted_document",
  } as const;

  test("Word, Excel, PowerPoint and an encrypted OOXML package", async () => {
    expect(
      await analyzeBytes(
        buildDoc({ word: wordDocumentStream({ encrypted: true }) }),
        DOC_MEDIA_TYPE,
      ),
    ).toEqual(encrypted);
    expect(
      await analyzeBytes(
        buildXls({
          records: [biffRecord(0x002f, [0, 0]), biffBoundSheet("S")],
        }),
        XLS_MEDIA_TYPE,
      ),
    ).toEqual(encrypted);
    expect(
      await analyzeBytes(
        buildPpt({ extra: [{ path: ["EncryptedSummary"], data: "x" }] }),
        PPT_MEDIA_TYPE,
      ),
    ).toEqual(encrypted);
    expect(
      await analyzeBytes(
        buildPpt({ records: [pptRecord(0x2f14, [])] }),
        PPT_MEDIA_TYPE,
      ),
    ).toEqual(encrypted);
    // A password-protected .docx is a compound file with no main stream.
    const package_ = buildCfb([
      { path: ["EncryptionInfo"], data: "x" },
      { path: ["EncryptedPackage"], data: "y" },
    ]);
    expect(detectCfbMediaType(package_)).toBeNull();
    expect(parseCfb(package_, "doc")).toEqual({
      ok: false,
      reason: "encrypted",
    });
  });
});

describe("hostile structure stays bounded", () => {
  test("each stream is reassembled and scanned for EICAR", () => {
    // parseCfb finds it itself, across a 64-byte mini sector edge.
    const file = buildCfb([
      { path: ["WordDocument"], data: wordDocumentStream() },
      { path: ["Data"], data: "f".repeat(60) + EICAR_SIGNATURE },
    ]);
    expect(parseCfb(file, "doc")).toEqual({ ok: false, reason: "malicious" });
  });

  test("a FAT loop or a cross-linked chain is malformed", () => {
    const big = new Uint8Array(6000);
    const { bytes, layout } = buildCfbDetailed([
      { path: ["WordDocument"], data: wordDocumentStream() },
      { path: ["Data"], data: big },
    ]);
    const chain = layout.streamSectors.get("Data")!;
    const looped = bytes.slice();
    setCfbFatEntry(looped, layout, chain[3]!, chain[1]!);
    expect(readCfbDirectory(looped)).toEqual({
      ok: false,
      reason: "malformed",
    });
    const crossLinked = bytes.slice();
    setCfbFatEntry(crossLinked, layout, chain[0]!, layout.directorySectors[0]!);
    expect(readCfbDirectory(crossLinked).ok).toBe(false);
    const outside = bytes.slice();
    setCfbFatEntry(outside, layout, chain[0]!, 0x00ffffff);
    expect(readCfbDirectory(outside).ok).toBe(false);
  });

  test("a directory sibling loop is malformed", () => {
    const { bytes, layout } = buildCfbDetailed([
      { path: ["WordDocument"], data: wordDocumentStream() },
      { path: ["A"], data: "x" },
    ]);
    // The root's first child gets itself as its right sibling.
    const looped = bytes.slice();
    const view = new DataView(looped.buffer);
    const dir = cfbSectorOffset(layout.directorySectors[0]!);
    const child = view.getUint32(dir + 0x4c, true);
    view.setUint32(dir + child * 128 + 0x48, child, true);
    expect(readCfbDirectory(looped)).toEqual({
      ok: false,
      reason: "malformed",
    });
  });

  test("a stream longer than its chain, or a bad header, is malformed", () => {
    const { bytes, layout } = buildCfbDetailed([
      { path: ["WordDocument"], data: wordDocumentStream() },
    ]);
    const view = (b: Uint8Array) => new DataView(b.buffer);
    const longer = bytes.slice();
    const dir = cfbSectorOffset(layout.directorySectors[0]!);
    // Entry 1 (WordDocument) claims 1 MB.
    view(longer).setUint32(dir + 128 + 0x78, 1_000_000, true);
    expect(readCfbDirectory(longer).ok).toBe(false);
    const badOrder = bytes.slice();
    view(badOrder).setUint16(0x1c, 0xfeff, true);
    expect(readCfbDirectory(badOrder).ok).toBe(false);
    const badShift = bytes.slice();
    view(badShift).setUint16(0x1e, 10, true);
    expect(readCfbDirectory(badShift).ok).toBe(false);
    expect(readCfbDirectory(bytes.slice(0, 300)).ok).toBe(false);
    expect(readCfbDirectory(new Uint8Array(4096)).ok).toBe(false);
  });

  test("a ZIP or PDF riding along is a polyglot", () => {
    const zip = new Uint8Array([
      ...buildDoc(),
      ...new Uint8Array(512),
      0x50,
      0x4b,
      0x05,
      0x06,
      ...new Uint8Array(18),
    ]);
    expect(readCfbDirectory(zip)).toEqual({ ok: false, reason: "polyglot" });
    const pdf = buildDoc();
    pdf.set(new TextEncoder().encode("%PDF-1.7"), 600);
    expect(readCfbDirectory(pdf)).toEqual({ ok: false, reason: "polyglot" });
  });

  test("garbage, truncation and a missing signature never throw", () => {
    const file = buildPpt();
    for (let cut = 0; cut < file.length; cut += 97) {
      expect(() => parseCfb(file.slice(0, cut), "ppt")).not.toThrow();
    }
    let seed = 7;
    for (let round = 0; round < 200; round++) {
      const noisy = file.slice();
      for (let k = 0; k < 8; k++) {
        seed = (seed * 1103515245 + 12345) >>> 0;
        noisy[512 + (seed % (noisy.length - 512))] = seed & 0xff;
      }
      expect(() => parseCfb(noisy, "ppt")).not.toThrow();
    }
    expect(parseCfb(new TextEncoder().encode("not a compound file"), "doc"))
      .toEqual({ ok: false, reason: "malformed" });
  });

  test("an overrunning presentation record inside a container is malformed", () => {
    const record = pptRecord(0x03e8, [pptRecord(0x03e9, new Uint8Array(40))]);
    // The inner atom claims more bytes than its container holds.
    new DataView(record.buffer).setUint32(8 + 4, 4000, true);
    expect(parseCfb(buildPpt({ records: [record] }), "ppt")).toEqual({
      ok: false,
      reason: "malformed",
    });
  });
});
