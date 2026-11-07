import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { renderPage } from "../src/render";
import { LANGS, pathFor, publishedPages, routeFor } from "../src/routes";

const root = join(import.meta.dir, "..");
const template = readFileSync(join(root, "index.html"), "utf8");

function pages() {
  return LANGS.flatMap((lang) =>
    publishedPages().map((page) => ({ page, lang }))
  );
}

describe("prerendered pages", () => {
  test("the School Portal page stays unpublished until the switch is on", () => {
    expect(publishedPages()).not.toContain("schools");
    expect(routeFor("/schools").page).toBe("notFound");
    for (const { page, lang } of pages()) {
      expect(renderPage(template, page, lang)).not.toContain('href="/schools"');
    }
  });

  test("addresses and pages map both ways", () => {
    for (const { page, lang } of pages()) {
      expect(routeFor(pathFor(page, lang))).toEqual({ page, lang });
    }
    expect(pathFor("home", "ar")).toBe("/ar");
    expect(pathFor("features", "ar")).toBe("/ar/features");
  });

  test.each(pages())(
    "$lang $page: language, title and links to the other language",
    ({ page, lang }) => {
      const html = renderPage(template, page, lang);
      expect(html).toContain(
        `<html lang="${lang}" dir="${lang === "ar" ? "rtl" : "ltr"}">`,
      );
      expect(html).toMatch(/<title>[^<]+<\/title>/);
      expect(html).toContain(`data-page="${page}" data-lang="${lang}"`);
      expect(html).toContain('<link rel="alternate" hreflang="ar"');
      expect(html).toContain(
        `<link rel="canonical" href="https://studafy.com${
          pathFor(page, lang)
        }"`,
      );
      expect(html).not.toContain("<!--app-->");
    },
  );

  test.each(pages())(
    "$lang $page: nothing the Content-Security-Policy would block",
    ({ page, lang }) => {
      const html = renderPage(template, page, lang);
      // Inline scripts and style attributes would need 'unsafe-inline'.
      expect(html).not.toMatch(/<script(?![^>]*\bsrc=)[^>]*>/);
      expect(html).not.toMatch(/\sstyle="/);
      // Everything loads from this site, except store pages and the legal site (links only).
      for (const [, src] of html.matchAll(/\ssrc="([^"]+)"/g)) {
        expect(src?.startsWith("/"), src).toBe(true);
      }
    },
  );

  test.each(pages())(
    "$lang $page: every link inside the site goes to a published page or file",
    ({ page, lang }) => {
      const html = renderPage(template, page, lang);
      for (const [, href] of html.matchAll(/\shref="(\/[^"#?]*)/g)) {
        if (!href) continue;
        const file = join(root, "public", href);
        const isFile = existsSync(file) && !href.endsWith("/");
        const isPage = routeFor(href).page !== "notFound";
        expect(isFile || isPage || href === "/src/main.tsx", href).toBe(true);
      }
    },
  );

  test("pictures carry text alternatives", () => {
    for (const { page, lang } of pages()) {
      const html = renderPage(template, page, lang);
      for (const [tag] of html.matchAll(/<img\b[^>]*>/g)) {
        expect(tag, tag).toMatch(/\salt="/);
      }
    }
  });
});
