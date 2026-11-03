import { describe, expect, test } from "bun:test";
import { createCanvas } from "@napi-rs/canvas";
import {
  buildDocx,
  buildPdf,
  buildPptx,
  buildXlsx,
  buildZip,
} from "@studafy/test-support";
import {
  CSV_MEDIA_TYPE,
  DOCX_MEDIA_TYPE,
  PPTX_MEDIA_TYPE,
  XLSX_MEDIA_TYPE,
} from "@studafy/domain";
import {
  chunkSections,
  extractCsv,
  extractXlsx,
  fetchPublicLink,
  isBlockedAddress,
  type MaterialReadDeps,
  readMaterial,
  SPREADSHEET_LIMITS,
} from "../src";

/**
 * Reading lesson files and links into passages (ADR-0037). The model is a
 * fake here: what is checked is what reaches it, when, and what comes back.
 */

const limits = {
  ocrPagesPerFile: 60,
  textPagesPerFile: 500,
  charsPerDocument: 600_000,
  linkMaxBytes: 3_000_000,
};

function deps(overrides: Partial<MaterialReadDeps> = {}) {
  const pages: Uint8Array[] = [];
  const asked: number[] = [];
  const base: MaterialReadDeps = {
    limits,
    ocrAllowance: (n) => {
      asked.push(n);
      return Promise.resolve(n);
    },
    readPage: (jpeg) => {
      pages.push(jpeg);
      return Promise.resolve({
        text:
          "الدرس الثالث: البناء الضوئي\nتقوم النباتات بتحويل الطاقة الضوئية.",
        usage: { inputTokens: 817, outputTokens: 78, model: "Qwen/Qwen3.5-9B" },
      });
    },
    readImage: () =>
      Promise.resolve({
        text: "Leaf\nDiagram: a leaf cross-section showing the stomata.",
        usage: { inputTokens: 900, outputTokens: 40, model: "Qwen/Qwen3.5-9B" },
      }),
  };
  return { deps: { ...base, ...overrides }, pages, asked };
}

async function photo(): Promise<Uint8Array> {
  const canvas = createCanvas(400, 300);
  const g = canvas.getContext("2d");
  g.fillStyle = "#fff";
  g.fillRect(0, 0, 400, 300);
  g.fillStyle = "#000";
  g.fillRect(40, 40, 200, 30);
  return new Uint8Array(await canvas.encode("jpeg", 80));
}

describe("Word and PowerPoint", () => {
  test("a Word file keeps its headings, tables and page breaks", async () => {
    const file = buildDocx([
      { heading: "Photosynthesis" },
      { paragraph: "Plants turn light into chemical energy." },
      { table: [["Stage", "Where"], ["Light reactions", "Thylakoid"]] },
      { pageBreak: true },
      { heading: "The Calvin cycle" },
      { paragraph: "Carbon dioxide is fixed into sugar." },
    ]);
    const result = await readMaterial(
      { kind: "file", mediaType: DOCX_MEDIA_TYPE, bytes: file },
      deps().deps,
    );
    expect(result.outcome).toBe("ready");
    expect(result.chunks).toEqual([
      {
        page: 1,
        slide: null,
        heading: "Photosynthesis",
        body:
          "Plants turn light into chemical energy.\n\nStage | Where\nLight reactions | Thylakoid",
      },
      {
        page: 2,
        slide: null,
        heading: "The Calvin cycle",
        body: "Carbon dioxide is fixed into sugar.",
      },
    ]);
  });

  test("a deck is read in slide order, with titles and speaker notes", async () => {
    const deck = buildPptx([
      { title: "Cells", lines: ["Every living thing is made of cells."] },
      {
        title: "Organelles",
        lines: ["Mitochondria release energy."],
        notes: "Ask about ATP.",
      },
    ]);
    const result = await readMaterial(
      { kind: "file", mediaType: PPTX_MEDIA_TYPE, bytes: deck },
      deps().deps,
    );
    expect(result.chunks.map((c) => [c.slide, c.heading, c.body])).toEqual([
      [1, "Cells", "Every living thing is made of cells."],
      [
        2,
        "Organelles",
        "Mitochondria release energy.\n\nSpeaker notes: Ask about ATP.",
      ],
    ]);
    expect(result.detail["slides"]).toBe(2);
  });

  test("an empty document is unsupported, and says why", async () => {
    const result = await readMaterial(
      { kind: "file", mediaType: DOCX_MEDIA_TYPE, bytes: buildDocx([]) },
      deps().deps,
    );
    expect(result).toMatchObject({ outcome: "unsupported", reason: "no_text" });
  });
});

describe("Excel and CSV", () => {
  const encode = (text: string) => new TextEncoder().encode(text);

  test("a workbook is read sheet by sheet: strings, numbers, booleans, formulas, dates", async () => {
    const book = buildXlsx([
      {
        name: "Marks",
        rows: [
          ["Name", "Score", "Passed", "Out of 20"],
          ["Lina", 18, true, { formula: "B2/20", cached: 0.9 }],
          [],
          ["Omar", 0.1 + 0.2, false, {
            formula: 'IF(B4>10,"yes","no")',
            cached: "no",
          }],
        ],
      },
      {
        name: "Dates",
        rows: [[{ inline: "Exam" }, { date: 46329 }]],
      },
    ]);
    const result = await readMaterial(
      { kind: "file", mediaType: XLSX_MEDIA_TYPE, bytes: book },
      deps().deps,
    );
    expect(result.outcome).toBe("ready");
    expect(result.reason).toBeNull();
    expect(result.extractor).toBe("xlsx-v1");
    expect(result.chunks.map((c) => [c.heading, c.body])).toEqual([
      [
        "Marks",
        "Name | Score | Passed | Out of 20\nLina | 18 | TRUE | 0.9\nOmar | 0.3 | FALSE | no",
      ],
      ["Dates", "Exam | 2026-11-03"],
    ]);
    expect(result.detail).toMatchObject({ sheets: 2, rows: 4 });
  });

  test("hidden sheets, rows and columns are not read", async () => {
    const book = buildXlsx([
      {
        name: "Questions",
        rows: [["Q", "Answer", "Topic"], ["Two and two", "4", "Sums"], [
          "Three threes",
          "9",
          "Times",
        ]],
        hiddenColumns: [2],
        hiddenRows: [3],
      },
      { name: "Key", rows: [["Secret answers"]], state: "hidden" },
      { name: "Key2", rows: [["More secrets"]], state: "veryHidden" },
    ]);
    const result = await readMaterial(
      { kind: "file", mediaType: XLSX_MEDIA_TYPE, bytes: book },
      deps().deps,
    );
    expect(result.chunks.map((c) => [c.heading, c.body])).toEqual([
      ["Questions", "Q | Topic\nTwo and two | Sums"],
    ]);
  });

  test("a long sheet is split into passages that each repeat the header row", async () => {
    const rows = [["Element", "Symbol", "Number"]];
    for (let n = 1; n <= 120; n++) rows.push([`Element ${n}`, `E${n}`, `${n}`]);
    const result = await readMaterial(
      {
        kind: "file",
        mediaType: XLSX_MEDIA_TYPE,
        bytes: buildXlsx([{ name: "Table", rows }]),
      },
      deps().deps,
    );
    expect(result.chunks.length).toBeGreaterThan(2);
    for (const chunk of result.chunks) {
      expect(chunk.heading).toBe("Table");
      expect(chunk.body.startsWith("Element | Symbol | Number\n")).toBe(true);
    }
    const body = result.chunks.map((c) => c.body).join("\n");
    expect(body).toContain("Element 120 | E120 | 120");
    expect(result.reason).toBeNull();
  });

  test("past the caps the rest is left out and the file is partly read", async () => {
    const rows = Array.from(
      { length: SPREADSHEET_LIMITS.rows + 50 },
      (_, n) => [`r${n}`],
    );
    const capped = await readMaterial(
      {
        kind: "file",
        mediaType: XLSX_MEDIA_TYPE,
        bytes: buildXlsx([{ name: "Long", rows }]),
      },
      deps().deps,
    );
    expect(capped.outcome).toBe("ready");
    expect(capped.reason).toBe("partly_read");
    expect(capped.detail["rows"]).toBe(SPREADSHEET_LIMITS.rows);

    // The per-file character cap stops the reading too.
    const small = await readMaterial(
      {
        kind: "file",
        mediaType: CSV_MEDIA_TYPE,
        bytes: encode("a,b\nc,d\ne,f\ng,h\n"),
      },
      deps({ limits: { ...limits, charsPerDocument: 12 } }).deps,
    );
    expect(small.reason).toBe("partly_read");
    expect(small.chunks.map((c) => c.body)).toEqual(["a | b\nc | d"]);

    // Too many columns.
    const wide = extractCsv(
      encode(Array.from({ length: 150 }, (_, i) => `c${i}`).join(",")),
    );
    expect(wide.truncated).toBe(true);
    expect(wide.sections[0]!.text.split(" | ")).toHaveLength(
      SPREADSHEET_LIMITS.columns,
    );
  });

  test("a CSV keeps quoted separators, doubled quotes and line breaks in a cell", async () => {
    const file = encode(
      '﻿Term,Meaning\r\n"cell, plant","the ""unit"" of life\nin plants"\r\n\r\nATP,energy\n',
    );
    const result = await readMaterial(
      { kind: "file", mediaType: CSV_MEDIA_TYPE, bytes: file },
      deps().deps,
    );
    expect(result.outcome).toBe("ready");
    expect(result.extractor).toBe("csv-v1");
    expect(result.chunks.map((c) => [c.heading, c.body])).toEqual([
      [
        null,
        'Term | Meaning\ncell, plant | the "unit" of life in plants\nATP | energy',
      ],
    ]);
    expect(result.detail["rows"]).toBe(3);
  });

  test("a semicolon or tab separated file is read by its own separator", () => {
    expect(extractCsv(encode("Name;Score\nLina;18,5\n")).sections[0]!.text)
      .toBe("Name | Score\nLina | 18,5");
    expect(extractCsv(encode("Name\tScore\nLina\t18\n")).sections[0]!.text)
      .toBe("Name | Score\nLina | 18");
  });

  test("a sheet of unclosed rows and cells is read in one pass", () => {
    const sheet =
      `<worksheet><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>kept</t></is></c></row>${
        "<row><c><v>1".repeat(200_000)
      }</sheetData></worksheet>`;
    const book = buildZip([
      {
        name: "[Content_Types].xml",
        data:
          '<Types><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/></Types>',
      },
      {
        name: "xl/workbook.xml",
        data:
          '<workbook><sheets><sheet name="S" r:id="rId1"/></sheets></workbook>',
      },
      {
        name: "xl/_rels/workbook.xml.rels",
        data:
          '<Relationships><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      },
      // Stored, so the size ratio does not refuse it first.
      { name: "xl/worksheets/sheet1.xml", data: sheet, stored: true },
    ]);
    const started = performance.now();
    const read = extractXlsx(book);
    expect(performance.now() - started).toBeLessThan(2_000);
    expect(read.sections.map((s) => s.text)).toEqual(["kept"]);
  });

  test("an empty table is unsupported; bytes that are not one are unreadable", async () => {
    expect(
      await readMaterial(
        { kind: "file", mediaType: CSV_MEDIA_TYPE, bytes: encode(",,\n,,\n") },
        deps().deps,
      ),
    ).toMatchObject({ outcome: "unsupported", reason: "no_text" });
    const notZip = encode("%PDF-1.7 not a workbook");
    expect(
      await readMaterial(
        { kind: "file", mediaType: XLSX_MEDIA_TYPE, bytes: notZip },
        deps().deps,
      ),
    ).toMatchObject({ outcome: "unsupported", reason: "unreadable_file" });
    expect(
      await readMaterial(
        {
          kind: "file",
          mediaType: CSV_MEDIA_TYPE,
          bytes: new Uint8Array([0x00, 0xff]),
        },
        deps().deps,
      ),
    ).toMatchObject({ outcome: "unsupported", reason: "unreadable_file" });
  });
});

describe("PDFs", () => {
  test("a text PDF is read page by page, without the model", async () => {
    const file = buildPdf([
      { text: ["Photosynthesis", "Plants turn light into chemical energy."] },
      { text: ["The Calvin cycle fixes carbon dioxide into sugar."] },
    ]);
    const { deps: d, pages } = deps();
    const result = await readMaterial({
      kind: "file",
      mediaType: "application/pdf",
      bytes: file,
    }, d);
    expect(result.outcome).toBe("ready");
    expect(result.chunks.map((c) => c.page)).toEqual([1, 2]);
    expect(result.chunks[1]!.body).toContain("Calvin cycle");
    expect(pages).toHaveLength(0);
    expect(result.usage).toEqual([]);
  });

  test("a scanned page is drawn and read by the model, within the budget", async () => {
    const file = buildPdf([
      { text: ["Introduction to photosynthesis for grade seven."] },
      { jpeg: await photo(), width: 400, height: 300 },
    ]);
    const { deps: d, pages, asked } = deps();
    const result = await readMaterial({
      kind: "file",
      mediaType: "application/pdf",
      bytes: file,
    }, d);
    expect(asked).toEqual([1]);
    expect(pages).toHaveLength(1);
    // A JPEG went to the model, not the PDF.
    expect([...pages[0]!.subarray(0, 2)]).toEqual([0xff, 0xd8]);
    expect(result.chunks.find((c) => c.page === 2)?.body).toContain(
      "البناء الضوئي",
    );
    expect(result.detail["ocrPages"]).toBe(1);
    expect(result.usage[0]).toMatchObject({
      kind: "ocr",
      pages: 1,
      inputTokens: 817,
    });
  });

  test("a scan over the school's budget is not read, and the file says so", async () => {
    const file = buildPdf([{ jpeg: await photo(), width: 400, height: 300 }]);
    const { deps: d, pages } = deps({ ocrAllowance: () => Promise.resolve(0) });
    const result = await readMaterial({
      kind: "file",
      mediaType: "application/pdf",
      bytes: file,
    }, d);
    expect(pages).toHaveLength(0);
    expect(result).toMatchObject({
      outcome: "unsupported",
      reason: "reading_budget_used",
    });
  });

  test("with no model a scan cannot be read", async () => {
    const file = buildPdf([{ jpeg: await photo(), width: 400, height: 300 }]);
    const result = await readMaterial(
      { kind: "file", mediaType: "application/pdf", bytes: file },
      deps({ readPage: null }).deps,
    );
    expect(result).toMatchObject({
      outcome: "unsupported",
      reason: "needs_model",
    });
  });

  test("a model failure is thrown, so the worker tries again later", async () => {
    const file = buildPdf([{ jpeg: await photo(), width: 400, height: 300 }]);
    const failing = Object.assign(new Error("study_assistant_unavailable"), {
      kind: "unavailable",
    });
    await expect(readMaterial(
      { kind: "file", mediaType: "application/pdf", bytes: file },
      deps({ readPage: () => Promise.reject(failing) }).deps,
    )).rejects.toBe(failing);
  });
});

describe("images", () => {
  test("a picture is shrunk, read and described", async () => {
    const big = createCanvas(4000, 3000);
    big.getContext("2d").fillRect(0, 0, 10, 10);
    let seen: Uint8Array | undefined;
    const result = await readMaterial(
      {
        kind: "file",
        mediaType: "image/jpeg",
        bytes: new Uint8Array(await big.encode("jpeg", 70)),
      },
      deps({
        readImage: (jpeg) => {
          seen = jpeg;
          return Promise.resolve({ text: "Diagram: a labelled leaf." });
        },
      }).deps,
    );
    expect(result.outcome).toBe("ready");
    const { loadImage } = await import("@napi-rs/canvas");
    const sent = await loadImage(Buffer.from(seen!));
    expect(Math.max(sent.width, sent.height)).toBe(1600);
  });
});

describe("links", () => {
  const page = (
    html: string,
    type = "text/html; charset=utf-8",
    status = 200,
  ) =>
    (() =>
      Promise.resolve(
        new Response(html, { status, headers: { "content-type": type } }),
      )) as unknown as typeof fetch;
  const publicDns = () => Promise.resolve(["93.184.216.34"]);

  test("addresses inside any private network are refused", () => {
    for (
      const address of [
        "127.0.0.1",
        "10.1.2.3",
        "172.20.0.1",
        "192.168.1.109",
        "169.254.169.254",
        "100.64.0.1",
        "0.0.0.0",
        "::1",
        "fdaa:0:1::3",
        "fe80::1",
        "::ffff:10.0.0.1",
      ]
    ) {
      expect(isBlockedAddress(address)).toBe(true);
    }
    expect(isBlockedAddress("93.184.216.34")).toBe(false);
    expect(isBlockedAddress("2606:4700::6810:85e5")).toBe(false);
  });

  test("a name that resolves to a private address is never fetched", async () => {
    let fetched = false;
    const result = await fetchPublicLink("https://intranet.example.com/", {
      maxBytes: 1000,
      resolve: () => Promise.resolve(["10.0.0.5"]),
      fetchImpl: (() => {
        fetched = true;
        return Promise.resolve(new Response("x"));
      }) as unknown as typeof fetch,
    });
    expect(result).toEqual({ ok: false, reason: "link_blocked_address" });
    expect(fetched).toBe(false);
  });

  test("a redirect into a private network is refused", async () => {
    const result = await fetchPublicLink("https://example.com/", {
      maxBytes: 1000,
      resolve: (host) =>
        Promise.resolve(
          host === "example.com" ? ["93.184.216.34"] : ["169.254.169.254"],
        ),
      fetchImpl: (() =>
        Promise.resolve(
          new Response(null, {
            status: 302,
            headers: { location: "https://metadata.internal.example/" },
          }),
        )) as unknown as typeof fetch,
    });
    expect(result).toEqual({ ok: false, reason: "link_blocked_address" });
  });

  test("plain http, other ports and credentials are refused", async () => {
    for (
      const url of [
        "http://example.com/",
        "https://example.com:8443/",
        "https://u:p@example.com/",
      ]
    ) {
      expect(await fetchPublicLink(url, { maxBytes: 10, resolve: publicDns }))
        .toEqual({
          ok: false,
          reason: "link_blocked_address",
        });
    }
  });

  test("what cannot be read says why", async () => {
    expect(
      await fetchPublicLink("https://www.youtube.com/watch?v=1", {
        maxBytes: 10,
        resolve: publicDns,
      }),
    )
      .toEqual({ ok: false, reason: "link_video" });
    expect(
      await fetchPublicLink("https://example.com/", {
        maxBytes: 10,
        resolve: publicDns,
        fetchImpl: page("no", "text/html", 403),
      }),
    )
      .toEqual({ ok: false, reason: "link_needs_sign_in" });
    expect(
      await fetchPublicLink("https://example.com/", {
        maxBytes: 10,
        resolve: publicDns,
        fetchImpl: page("x", "image/png"),
      }),
    )
      .toEqual({ ok: false, reason: "link_unsupported_type" });
  });

  test("a web page is read as headed text, scripts and menus dropped", async () => {
    const html =
      `<html><head><title>Cells</title><script>steal()</script></head><body>
      <nav>Home | About</nav><article><h1>Animal cells</h1><p>Animal cells have no wall &amp; no chloroplasts.</p>
      <h2>Plant cells</h2><p>Plant cells have a cell wall.</p></article></body></html>`;
    const result = await readMaterial(
      { kind: "link", url: "https://example.com/cells" },
      deps({
        fetchLink: (url) =>
          fetchPublicLink(url, {
            maxBytes: 100_000,
            resolve: publicDns,
            fetchImpl: page(html),
          }),
      }).deps,
    );
    expect(result.chunks.map((c) => [c.heading, c.body])).toEqual([
      ["Animal cells", "Animal cells have no wall & no chloroplasts."],
      ["Plant cells", "Plant cells have a cell wall."],
    ]);
    expect(JSON.stringify(result.chunks)).not.toContain("steal");
    expect(JSON.stringify(result.chunks)).not.toContain("Home");
  });

  test("a page larger than the cap is kept up to the cap", async () => {
    const result = await fetchPublicLink("https://example.com/", {
      maxBytes: 100,
      resolve: publicDns,
      fetchImpl: page("a".repeat(1000), "text/plain"),
    });
    expect(result).toMatchObject({ ok: true, truncated: true });
    expect(result.ok && result.bytes.length).toBe(100);
  });
});

describe("passages", () => {
  test("never cross a page and stay near the target size", () => {
    const long = Array.from(
      { length: 40 },
      (_, i) => `Sentence number ${i} about cells and energy.`,
    ).join(" ");
    const { chunks } = chunkSections([
      { page: 1, text: long },
      { page: 2, text: "Short page." },
    ], 100_000);
    expect(chunks.every((c) => c.body.length <= 1600)).toBe(true);
    expect(chunks.at(-1)).toEqual({
      page: 2,
      slide: null,
      heading: null,
      body: "Short page.",
    });
    expect(new Set(chunks.filter((c) => c.page === 1).map((c) => c.page)))
      .toEqual(new Set([1]));
  });

  test("stop at the per-document limit and say so", () => {
    const result = chunkSections([{ text: "word ".repeat(5000) }], 2000);
    expect(result.truncated).toBe(true);
    expect(result.chars).toBeLessThanOrEqual(2000 + 1600);
  });
});
