// The Markdown the legal documents in docs/legal use, and nothing more:
// headings, paragraphs (a trailing backslash is a line break), bulleted and
// numbered lists one level deep, tables, block quotes, rules, bold, inline
// code and links. HTML comments are removed: they hold the legal-review
// notes, which must never reach a published page (launch plan 4.3).

export interface Heading {
  level: number;
  id: string | undefined;
  text: string;
}

export interface Rendered {
  html: string;
  title: string;
  headings: Heading[];
}

export function stripComments(markdown: string): string {
  return markdown.replace(/<!--[\s\S]*?-->\n?/g, "");
}

export function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

const EMAIL = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;

export function inline(text: string): string {
  const codes: string[] = [];
  const links: string[] = [];
  let out = text.replace(/`([^`]+)`/g, (_, code: string) => {
    codes.push(`<code dir="ltr">${escapeHtml(code)}</code>`);
    return `\uE000c${codes.length - 1}\uE000`;
  });
  out = out.replace(
    /\[([^\]]+)\]\(([^)\s]+)\)/g,
    (_, label: string, href: string) => {
      links.push(`<a href="${escapeHtml(href)}">${inlineText(label)}</a>`);
      return `\uE000l${links.length - 1}\uE000`;
    },
  );
  out = inlineText(out);
  return out
    .replace(/\uE000c(\d+)\uE000/g, (_, i: string) => codes[Number(i)])
    .replace(/\uE000l(\d+)\uE000/g, (_, i: string) => links[Number(i)]);
}

function inlineText(text: string): string {
  return escapeHtml(text)
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(
      EMAIL,
      (email) => `<a href="mailto:${email}" dir="ltr">${email}</a>`,
    );
}

// "6. The AI study tools" -> "s6"; "7.2 Our processors" -> "s7-2".
export function sectionId(text: string): string | undefined {
  const match = /^(\d+(?:\.\d+)*)\.?\s/.exec(text);
  return match ? `s${match[1].replaceAll(".", "-")}` : undefined;
}

function cells(row: string): string[] {
  return row.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((
    cell,
  ) => cell.trim());
}

const BULLET = /^- /;
const NUMBERED = /^\d+\. /;
const NESTED_BULLET = /^ {2,3}- /;

export function render(markdown: string): Rendered {
  const lines = stripComments(markdown).replace(/\r\n/g, "\n").split("\n");
  const html: string[] = [];
  const headings: Heading[] = [];
  let title = "";
  let i = 0;

  const joinParagraph = (block: string[]): string => {
    const parts: string[] = [];
    block.forEach((line, index) => {
      const hardBreak = line.endsWith("\\");
      const text = inline(line.replace(/\\$/, "").trim());
      parts.push(text);
      if (index < block.length - 1) parts.push(hardBreak ? "<br>" : " ");
    });
    return `<p>${parts.join("")}</p>`;
  };

  while (i < lines.length) {
    const line = lines[i];
    if (line.trim() === "") {
      i++;
      continue;
    }

    const heading = /^(#{1,4})\s+(.*)$/.exec(line);
    if (heading) {
      const level = heading[1].length;
      const text = heading[2].trim();
      const id = level > 1 ? sectionId(text) : undefined;
      if (level === 1 && !title) title = text;
      headings.push({ level, id, text });
      html.push(
        `<h${level}${id ? ` id="${id}"` : ""}>${inline(text)}</h${level}>`,
      );
      i++;
      continue;
    }

    if (/^-{3,}\s*$/.test(line)) {
      html.push("<hr>");
      i++;
      continue;
    }

    if (line.startsWith(">")) {
      const block: string[] = [];
      while (i < lines.length && lines[i].startsWith(">")) {
        block.push(lines[i].replace(/^>\s?/, ""));
        i++;
      }
      const inner = block.join("\n").split(/\n\s*\n/).filter((p) => p.trim())
        .map((p) => joinParagraph(p.split("\n")));
      html.push(`<blockquote>${inner.join("")}</blockquote>`);
      continue;
    }

    if (
      line.trimStart().startsWith("|") && i + 1 < lines.length &&
      /^\s*\|?\s*:?-{3,}/.test(lines[i + 1])
    ) {
      const head = cells(line);
      i += 2;
      const rows: string[][] = [];
      while (i < lines.length && lines[i].trimStart().startsWith("|")) {
        rows.push(cells(lines[i]));
        i++;
      }
      html.push(
        `<div class="table"><table><thead><tr>${
          head.map((cell) => `<th>${inline(cell)}</th>`).join("")
        }</tr></thead><tbody>${
          rows.map((row) =>
            `<tr>${row.map((cell) => `<td>${inline(cell)}</td>`).join("")}</tr>`
          ).join("")
        }</tbody></table></div>`,
      );
      continue;
    }

    if (BULLET.test(line) || NUMBERED.test(line)) {
      const ordered = NUMBERED.test(line);
      const marker = ordered ? NUMBERED : BULLET;
      const items: string[] = [];
      while (i < lines.length && marker.test(lines[i])) {
        const text = [lines[i].replace(marker, "")];
        const nested: string[] = [];
        i++;
        while (
          i < lines.length && lines[i].trim() !== "" &&
          !marker.test(lines[i]) && /^\s+/.test(lines[i])
        ) {
          if (NESTED_BULLET.test(lines[i])) {
            nested.push(lines[i].replace(NESTED_BULLET, ""));
          } else if (nested.length > 0) {
            nested[nested.length - 1] += ` ${lines[i].trim()}`;
          } else {
            text.push(lines[i].trim());
          }
          i++;
        }
        const sub = nested.length
          ? `<ul>${
            nested.map((item) => `<li>${inline(item.trim())}</li>`).join("")
          }</ul>`
          : "";
        items.push(`<li>${inline(text.join(" ").trim())}${sub}</li>`);
      }
      const tag = ordered ? "ol" : "ul";
      html.push(`<${tag}>${items.join("")}</${tag}>`);
      continue;
    }

    const block: string[] = [];
    while (
      i < lines.length && lines[i].trim() !== "" &&
      !/^(#{1,4})\s/.test(lines[i]) && !lines[i].startsWith(">") &&
      !BULLET.test(lines[i]) && !NUMBERED.test(lines[i]) &&
      !lines[i].trimStart().startsWith("|") && !/^-{3,}\s*$/.test(lines[i])
    ) {
      block.push(lines[i]);
      i++;
    }
    html.push(joinParagraph(block));
  }

  return { html: html.join("\n"), title, headings };
}
