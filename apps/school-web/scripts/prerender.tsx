/**
 * Writes every public page as plain HTML after `vite build`, so pages load
 * fast on slow phones and search engines can read them without running
 * the script. Run by `bun run build`.
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { config } from "../src/config";
import { renderPage } from "../src/render";
import { LANGS, pathFor, publishedPages } from "../src/routes";

/** Every published page in both languages, each naming its translation. */
function sitemap(): string {
  const entries = publishedPages().flatMap((page) =>
    LANGS.map((lang) => {
      const alternates = LANGS.map((other) =>
        `    <xhtml:link rel="alternate" hreflang="${other}" href="${config.siteUrl}${
          pathFor(page, other)
        }"/>`
      ).join("\n");
      return `  <url>\n    <loc>${config.siteUrl}${
        pathFor(page, lang)
      }</loc>\n${alternates}\n  </url>`;
    })
  );
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${entries.join("\n")}
</urlset>
`;
}

const dist = join(import.meta.dir, "..", "dist");
const template = readFileSync(join(dist, "index.html"), "utf8");

function write(relative: string, html: string) {
  const file = join(dist, relative);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, html);
}

let count = 0;
for (const lang of LANGS) {
  for (const page of publishedPages()) {
    const path = pathFor(page, lang);
    write(
      path === "/" ? "index.html" : `${path.slice(1)}/index.html`,
      renderPage(template, page, lang),
    );
    count += 1;
  }
}
write("404.html", renderPage(template, "notFound", "en"));
write("ar/404.html", renderPage(template, "notFound", "ar"));
write("sitemap.xml", sitemap());
write(
  "robots.txt",
  `User-agent: *\nAllow: /\n\nSitemap: ${config.siteUrl}/sitemap.xml\n`,
);

console.log(`prerendered ${count} pages, 2 not-found pages and the sitemap`);
