import { describe, expect, test } from "bun:test";
import { buildZip } from "@studafy/test-support";
import {
  extractDocx,
  extractPptx,
  UnreadableDocumentError,
} from "../src/material/office";

// File reading edge cases (launch plan 7.1): Word stores some characters as
// numeric entities, Arabic among them, and a file that is not a real Office
// file must be refused as unreadable rather than read as garbage.

const encode = (text: string) => new TextEncoder().encode(text);

function rawDocx(paragraphXml: string): Uint8Array {
  return buildZip([
    {
      name: "[Content_Types].xml",
      data: encode(
        `<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>`,
      ),
    },
    {
      name: "_rels/.rels",
      data: encode(
        `<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>`,
      ),
    },
    {
      name: "word/document.xml",
      data: encode(
        `<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${paragraphXml}</w:body></w:document>`,
      ),
    },
  ]);
}

describe("Office file reading", () => {
  test("numeric entities decode, Arabic included, and invalid ones are dropped", () => {
    const docx = rawDocx(
      `<w:p><w:r><w:t xml:space="preserve">&#x627;&#x644;&#1582;&#1604;&#1610;&#1577; &amp; cells &lt;3 &#0;&#x110000;</w:t></w:r></w:p>`,
    );
    const text = JSON.stringify(extractDocx(docx));
    expect(text).toContain("الخلية & cells <3");
    expect(text).not.toContain("&#");
  });

  test("bytes that are not an Office file are unreadable, for Word and PowerPoint", () => {
    const notZip = encode("%PDF-1.7 this is not a zip at all");
    expect(() => extractDocx(notZip)).toThrow(UnreadableDocumentError);
    expect(() => extractPptx(notZip)).toThrow(UnreadableDocumentError);
  });
});
