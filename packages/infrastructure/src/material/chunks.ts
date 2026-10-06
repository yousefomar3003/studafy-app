/**
 * Material split into passages a question can be matched against
 * (ADR-0037). A passage never crosses a page, a slide or a heading, so a
 * citation can name where it came from.
 */

/** A run of text with one location: a page, a slide, or a heading. */
export interface MaterialSection {
  page?: number | null;
  slide?: number | null;
  heading?: string | null;
  text: string;
}

export interface MaterialChunk {
  page: number | null;
  slide: number | null;
  heading: string | null;
  body: string;
}

/** About a paragraph or two: small enough to rank, big enough to explain. */
export const CHUNK_TARGET_CHARS = 1_100;
const CHUNK_MAX_CHARS = 1_600;

function normalise(text: string): string {
  return text
    .replace(/\r\n?/g, "\n")
    // deno-lint-ignore no-control-regex -- control bytes from extracted text
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, "")
    .replace(/[ \t ]+/g, " ")
    .replace(/ *\n */g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/** A paragraph too long for one passage, cut at sentence ends. */
function splitLong(paragraph: string): string[] {
  if (paragraph.length <= CHUNK_MAX_CHARS) return [paragraph];
  const sentences = paragraph.split(/(?<=[.!?؟。])\s+/);
  const out: string[] = [];
  let current = "";
  for (const sentence of sentences) {
    for (let at = 0; at < sentence.length; at += CHUNK_MAX_CHARS) {
      const piece = sentence.slice(at, at + CHUNK_MAX_CHARS);
      if (current.length + piece.length + 1 > CHUNK_TARGET_CHARS && current) {
        out.push(current);
        current = "";
      }
      current = current ? `${current} ${piece}` : piece;
    }
  }
  if (current) out.push(current);
  return out;
}

/**
 * The sections as passages, in order, stopping once [maxChars] of text has
 * been kept. Returns whether anything was left out.
 */
export function chunkSections(
  sections: MaterialSection[],
  maxChars: number,
): { chunks: MaterialChunk[]; chars: number; truncated: boolean } {
  const chunks: MaterialChunk[] = [];
  let chars = 0;
  for (const section of sections) {
    const text = normalise(section.text);
    if (!text) continue;
    const heading = section.heading
      ? normalise(section.heading).slice(0, 300)
      : null;
    const paragraphs = text.split(/\n{2,}|\n(?=[#\-•*\d])/).flatMap(splitLong);
    let current = "";
    const flush = () => {
      const body = current.trim();
      if (!body) return;
      chunks.push({
        page: section.page ?? null,
        slide: section.slide ?? null,
        heading,
        body,
      });
      chars += body.length;
      current = "";
    };
    for (const paragraph of paragraphs) {
      if (chars + current.length >= maxChars) {
        flush();
        return { chunks, chars, truncated: true };
      }
      if (
        current && current.length + paragraph.length + 2 > CHUNK_TARGET_CHARS
      ) {
        flush();
      }
      current = current ? `${current}\n\n${paragraph}` : paragraph;
    }
    flush();
    if (chars >= maxChars) return { chunks, chars, truncated: true };
  }
  return { chunks, chars, truncated: false };
}
