/**
 * PDFs built in code for tests (ADR-0037): pages of real text in a
 * standard font, and "scanned" pages that are only a picture.
 */

export type PdfPage =
  | { text: string[] }
  | { jpeg: Uint8Array; width: number; height: number };

const latin = (text: string) =>
  Uint8Array.from([...text].map((c) => c.charCodeAt(0) & 0xff));

function escapePdf(text: string): string {
  return text.replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(
    /\)/g,
    "\\)",
  );
}

/** A PDF with one page per entry. */
export function buildPdf(pages: PdfPage[]): Uint8Array {
  const objects: Uint8Array[] = [];
  const add = (body: Uint8Array | string) => {
    objects.push(typeof body === "string" ? latin(body) : body);
    return objects.length;
  };
  const stream = (dict: string, data: Uint8Array) =>
    Uint8Array.from([
      ...latin(`<< ${dict} /Length ${data.length} >>\nstream\n`),
      ...data,
      ...latin("\nendstream"),
    ]);

  add("<< /Type /Catalog /Pages 2 0 R >>");
  add(""); // the page tree, filled in below
  const font = add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");
  const kids: number[] = [];
  for (const page of pages) {
    let content: string;
    let resources: string;
    if ("text" in page) {
      content = `BT /F1 16 Tf 72 720 Td 20 TL ${
        page.text.map((line) => `(${escapePdf(line)}) Tj T*`).join(" ")
      } ET`;
      resources = `<< /Font << /F1 ${font} 0 R >> >>`;
    } else {
      const image = add(stream(
        `/Type /XObject /Subtype /Image /Width ${page.width} /Height ${page.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode`,
        page.jpeg,
      ));
      content = `q 612 0 0 792 0 0 cm /Im1 Do Q`;
      resources = `<< /XObject << /Im1 ${image} 0 R >> >>`;
    }
    const contents = add(stream("", latin(content)));
    kids.push(add(
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents ${contents} 0 R /Resources ${resources} >>`,
    ));
  }
  objects[1] = latin(
    `<< /Type /Pages /Kids [${
      kids.map((k) => `${k} 0 R`).join(" ")
    }] /Count ${kids.length} >>`,
  );

  const out: number[] = [...latin("%PDF-1.4\n")];
  const offsets: number[] = [];
  objects.forEach((body, index) => {
    offsets.push(out.length);
    out.push(...latin(`${index + 1} 0 obj\n`), ...body, ...latin("\nendobj\n"));
  });
  const xref = out.length;
  out.push(...latin(`xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`));
  for (const offset of offsets) {
    out.push(...latin(`${String(offset).padStart(10, "0")} 00000 n \n`));
  }
  out.push(...latin(
    `trailer\n<< /Size ${
      objects.length + 1
    } /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`,
  ));
  return Uint8Array.from(out);
}
