import { describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { inline, render, sectionId, stripComments } from "../src/markdown.ts";
import { build, pagePath, PAGES } from "../src/site.ts";

const root = join(import.meta.dirname ?? ".", "..");
const outDir = mkdtempSync(join(tmpdir(), "legal-site-"));
const written = build({
  sourceDir: join(root, "..", "..", "docs", "legal"),
  outDir,
  stylesheet: join(root, "src", "styles.css"),
});
const read = (path: string) => readFileSync(join(outDir, path), "utf8");
const page = (path: string) => read(`${path.slice(1)}.html`);
// What a reader sees: the page without tags.
const visible = (html: string) => html.replace(/<[^>]+>/g, " ");

describe("markdown", () => {
  test("comments never reach the page", () => {
    expect(stripComments("a\n<!-- TODO(legal): secret\nnote -->\nb")).toBe(
      "a\nb",
    );
    expect(render("# T\n\n<!-- TODO -->\ntext").html).not.toContain("TODO");
  });

  test("inline marks, links, code and emails", () => {
    expect(inline("**bold** `x<y` [Terms](terms) a@b.co")).toBe(
      '<strong>bold</strong> <code dir="ltr">x&lt;y</code> <a href="terms">Terms</a> <a href="mailto:a@b.co" dir="ltr">a@b.co</a>',
    );
  });

  test("numbered sections get stable anchors", () => {
    expect(sectionId("6. The AI study tools")).toBe("s6");
    expect(sectionId("7.2 Our processors")).toBe("s7-2");
    expect(sectionId("What changed")).toBeUndefined();
  });

  test("tables, nested lists and hard line breaks", () => {
    const { html } = render(
      "| A | B |\n|---|---|\n| 1 | 2 |\n\n- one\n  - inner\n    more\n- two\n\nline\\\nnext",
    );
    expect(html).toContain("<th>A</th><th>B</th>");
    expect(html).toContain("<td>1</td><td>2</td>");
    expect(html).toContain("<li>one<ul><li>inner more</li></ul></li>");
    expect(html).toContain("<p>line<br>next</p>");
  });
});

describe("the built site", () => {
  test("every page is built at its stable path, in both languages", () => {
    expect(written.sort()).toEqual([
      "/ar/delete-account",
      "/ar/privacy",
      "/ar/terms",
      "/delete-account",
      "/privacy",
      "/terms",
    ]);
  });

  test("English is left-to-right and Arabic right-to-left", () => {
    for (const p of PAGES) {
      expect(page(pagePath("en", p.key))).toContain(
        '<html lang="en" dir="ltr">',
      );
      expect(page(pagePath("ar", p.key))).toContain(
        '<html lang="ar" dir="rtl">',
      );
    }
  });

  test("no legal-review note or placeholder is visible", () => {
    for (const path of written) {
      const html = page(path);
      expect(html).not.toContain("<!--");
      expect(visible(html)).not.toMatch(
        /TODO|\[[A-Z][A-Z ,]+\]|BEFORE PUBLISHING/,
      );
    }
  });

  test("the controller and contact are named on every page", () => {
    for (const path of written) {
      const html = page(path);
      expect(html).toContain("Studafy Limited");
      expect(html).toContain("822430");
      expect(html).toContain("4/5 The Square, Cahir, Co. Tipperary, Ireland");
      expect(html).toContain('href="mailto:hello@studafy.com"');
    }
  });

  test("links never name a host, so a new domain is only configuration", () => {
    for (const path of written) {
      const hrefs = [...page(path).matchAll(/href="([^"]+)"/g)].map((m) =>
        m[1]
      );
      for (const href of hrefs) {
        expect(href).toMatch(/^(\/|mailto:|[a-z-]+$|\.\.\/[a-z-]+$|#)/);
      }
    }
  });

  test("each page links to its translation", () => {
    expect(page("/privacy")).toContain('href="/ar/privacy" lang="ar"');
    expect(page("/ar/terms")).toContain('href="/terms" lang="en"');
  });

  test("the deletion page gives the steps, the email route and the 14 days", () => {
    const en = visible(page("/delete-account"));
    expect(en).toContain("Delete account");
    expect(en).toContain("hello@studafy.com");
    expect(en).toContain("14 days");
    expect(visible(page("/ar/delete-account"))).toContain("14 يومًا");
  });

  test("headers and redirects are published with the pages", () => {
    expect(read("_headers")).toContain("frame-ancestors 'none'");
    expect(read("_redirects")).toContain("/ /privacy 302");
    expect(read("404.html")).toContain("Page not found");
  });
});
