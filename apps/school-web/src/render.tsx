import { renderToString } from "react-dom/server";
import { App } from "./App";
import { config } from "./config";
import { copyFor } from "./i18n";
import { dirFor, type Lang, LANGS, type PageId, pathFor } from "./routes";

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function head(page: PageId, lang: Lang): string {
  const meta = copyFor(lang).meta[page];
  const tags = [
    `<title>${escapeHtml(meta.title)}</title>`,
    `<meta name="description" content="${escapeHtml(meta.description)}" />`,
  ];
  if (page === "notFound") {
    tags.push(`<meta name="robots" content="noindex" />`);
    return tags.join("\n    ");
  }
  const url = (target: Lang) => `${config.siteUrl}${pathFor(page, target)}`;
  tags.push(
    `<link rel="canonical" href="${url(lang)}" />`,
    ...LANGS.map((target) =>
      `<link rel="alternate" hreflang="${target}" href="${url(target)}" />`
    ),
    `<link rel="alternate" hreflang="x-default" href="${url("en")}" />`,
    `<meta property="og:type" content="website" />`,
    `<meta property="og:site_name" content="Studafy" />`,
    `<meta property="og:title" content="${escapeHtml(meta.title)}" />`,
    `<meta property="og:description" content="${
      escapeHtml(meta.description)
    }" />`,
    `<meta property="og:url" content="${url(lang)}" />`,
    `<meta property="og:image" content="${config.siteUrl}/brand/share.jpg" />`,
    `<meta property="og:locale" content="${
      lang === "ar" ? "ar_JO" : "en_GB"
    }" />`,
    `<meta name="twitter:card" content="summary_large_image" />`,
  );
  return tags.join("\n    ");
}

/** A whole HTML page: the built template with the page rendered into it. */
export function renderPage(template: string, page: PageId, lang: Lang): string {
  const body = renderToString(<App page={page} lang={lang} />);
  return template
    .replace(
      '<html lang="en" dir="ltr">',
      `<html lang="${lang}" dir="${dirFor(lang)}">`,
    )
    .replace("<!--head-->", head(page, lang))
    // No whitespace may sit between the root and the page, or hydration
    // sees an extra text node; the formatter puts the marker on its own line.
    .replace(
      /<div id="root">\s*<!--app-->\s*<\/div>/,
      () =>
        `<div id="root" data-page="${page}" data-lang="${lang}">${body}</div>`,
    );
}
