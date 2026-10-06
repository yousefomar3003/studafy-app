/**
 * The readable text of a web page (ADR-0037): headings and paragraphs, with
 * scripts, styles, navigation, forms and embeds dropped. Nothing is run and
 * nothing it refers to is fetched.
 */
import type { MaterialSection } from "./chunks";

const ENTITIES: Record<string, string> = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: " ",
  ndash: "–",
  mdash: "—",
  hellip: "…",
  laquo: "«",
  raquo: "»",
};

export function decodeEntities(text: string): string {
  return text.replace(
    /&(#x[0-9a-f]{1,6}|#\d{1,7}|[a-z]{2,8});/gi,
    (all, code: string) => {
      if (code[0] === "#") {
        const n = code[1] === "x" || code[1] === "X"
          ? parseInt(code.slice(2), 16)
          : Number(code.slice(1));
        return n > 0 && n < 0x110000 ? String.fromCodePoint(n) : "";
      }
      return ENTITIES[code.toLowerCase()] ?? all;
    },
  );
}

export function htmlToSections(html: string): {
  title: string | null;
  sections: MaterialSection[];
} {
  const title = decodeEntities(
    html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1]?.replace(/\s+/g, " ")
      .trim() ?? "",
  ) || null;
  // Prefer the article itself when the page marks one.
  const main = html.match(/<(article|main)(?:\s[^>]*)?>[\s\S]*?<\/\1>/i)?.[0] ?? html;
  const cleaned = main
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(
      /<(script|style|noscript|svg|nav|footer|header|form|iframe|object|embed|template|aside|button|select)(?:\s[^>]*)?>[\s\S]*?<\/\1>/gi,
      " ",
    )
    .replace(/<(br|hr)\s*\/?>/gi, "\n")
    .replace(
      /<\/?(p|div|section|li|tr|table|ul|ol|blockquote|pre|dd|dt|figcaption)(?:\s[^>]*)?>/gi,
      "\n\n",
    )
    .replace(/<(td|th)(?:\s[^>]*)?>/gi, " | ")
    .replace(
      /<h([1-4])[^>]*>([\s\S]*?)<\/h\1>/gi,
      (_, __, inner: string) =>
        `\n\n\u0001${inner.replace(/<[^>]+>/g, " ")}\u0002\n\n`,
    )
    .replace(/<[^>]+>/g, " ");
  const text = decodeEntities(cleaned);
  const sections: MaterialSection[] = [];
  let heading: string | null = null;
  let buffer = "";
  const flush = () => {
    if (buffer.trim()) sections.push({ heading, text: buffer });
    buffer = "";
  };
  // deno-lint-ignore no-control-regex -- \u0001/\u0002 mark headings above
  for (const piece of text.split(/(\u0001[\s\S]*?\u0002)/)) {
    if (piece.startsWith("\u0001")) {
      flush();
      heading = piece.slice(1, -1).replace(/\s+/g, " ").trim().slice(0, 300) ||
        null;
    } else {
      buffer += piece;
    }
  }
  flush();
  return { title, sections };
}
