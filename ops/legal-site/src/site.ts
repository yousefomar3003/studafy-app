// Builds the public legal site (launch plan 4.3): the privacy policy, the
// terms and the account deletion page, in English and Arabic, from the
// Markdown in docs/legal, plus the app-link association files
// (app-links.ts). Every link is path-absolute or relative, so a host is only
// a route in wrangler.toml.

import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { appleAppSiteAssociation, assetLinks } from "./app-links.ts";
import { escapeHtml, render } from "./markdown.ts";

export type Locale = "en" | "ar";
export type PageKey = "privacy" | "terms" | "delete-account";

interface PageSource {
  key: PageKey;
  file: string;
  description: Record<Locale, string>;
}

export const PAGES: PageSource[] = [
  {
    key: "privacy",
    file: "privacy-policy.md",
    description: {
      en: "How Studafy Limited handles personal data in the Studafy app.",
      ar:
        "كيف تتعامل شركة Studafy Limited مع البيانات الشخصية في تطبيق Studafy.",
    },
  },
  {
    key: "terms",
    file: "terms-of-use.md",
    description: {
      en: "The terms for using the Studafy app.",
      ar: "شروط استخدام تطبيق Studafy.",
    },
  },
  {
    key: "delete-account",
    file: "delete-account.md",
    description: {
      en: "How to delete your Studafy account, and what is deleted and kept.",
      ar: "كيفية حذف حسابك في Studafy، وما الذي يُحذف وما الذي يبقى.",
    },
  },
];

const LABELS: Record<Locale, Record<PageKey | "switch" | "skip", string>> = {
  en: {
    privacy: "Privacy Policy",
    terms: "Terms of Use",
    "delete-account": "Delete your account",
    switch: "العربية",
    skip: "Skip to content",
  },
  ar: {
    privacy: "سياسة الخصوصية",
    terms: "شروط الاستخدام",
    "delete-account": "حذف حسابك",
    switch: "English",
    skip: "انتقل إلى المحتوى",
  },
};

const FOOTER: Record<Locale, string> = {
  en:
    'Studafy Limited · Company number 822430 · 4/5 The Square, Cahir, Co. Tipperary, Ireland · <a href="mailto:hello@studafy.com" dir="ltr">hello@studafy.com</a>',
  ar:
    'Studafy Limited · رقم الشركة 822430 · <span dir="ltr">4/5 The Square, Cahir, Co. Tipperary, Ireland</span> · <a href="mailto:hello@studafy.com" dir="ltr">hello@studafy.com</a>',
};

/** The published path of a page: /privacy, /ar/privacy. */
export function pagePath(locale: Locale, key: PageKey): string {
  return locale === "en" ? `/${key}` : `/${locale}/${key}`;
}

export function pageHtml(
  locale: Locale,
  page: PageSource,
  markdown: string,
): string {
  const { html, title } = render(markdown);
  const dir = locale === "ar" ? "rtl" : "ltr";
  const other: Locale = locale === "en" ? "ar" : "en";
  const labels = LABELS[locale];
  const nav = PAGES.map((p) =>
    `<a href="${pagePath(locale, p.key)}"${
      p.key === page.key ? ' aria-current="page"' : ""
    }>${labels[p.key]}</a>`
  ).join("");
  return `<!doctype html>
<html lang="${locale}" dir="${dir}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(page.description[locale])}">
<link rel="alternate" hreflang="en" href="${pagePath("en", page.key)}">
<link rel="alternate" hreflang="ar" href="${pagePath("ar", page.key)}">
<link rel="stylesheet" href="/styles.css">
</head>
<body>
<a class="skip" href="#content">${labels.skip}</a>
<header>
<div class="bar">
<span class="brand" dir="ltr">Studafy</span>
<a class="lang" href="${
    pagePath(other, page.key)
  }" lang="${other}" hreflang="${other}">${labels.switch}</a>
</div>
<nav aria-label="${locale === "ar" ? "الصفحات" : "Pages"}">${nav}</nav>
</header>
<main id="content">
${html}
</main>
<footer><p>${FOOTER[locale]}</p></footer>
</body>
</html>
`;
}

function notFoundHtml(): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Not found · Studafy</title>
<link rel="stylesheet" href="/styles.css">
</head>
<body>
<main id="content">
<h1>Page not found</h1>
<p><a href="/privacy">Privacy Policy</a> · <a href="/terms">Terms of Use</a> · <a href="/delete-account">Delete your account</a></p>
<p lang="ar" dir="rtl"><a href="/ar/privacy">سياسة الخصوصية</a> · <a href="/ar/terms">شروط الاستخدام</a> · <a href="/ar/delete-account">حذف حسابك</a></p>
</main>
</body>
</html>
`;
}

// Static assets read these two files (Cloudflare Workers static assets).
const HEADERS = `/*
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  Strict-Transport-Security: max-age=31536000
  Content-Security-Policy: default-src 'none'; style-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'
  Cache-Control: public, max-age=300

/.well-known/apple-app-site-association
  Content-Type: application/json
`;

const REDIRECTS = `/ /privacy 302
/ar /ar/privacy 302
/ar/ /ar/privacy 302
`;

export interface BuildOptions {
  /** docs/legal: English at the root, Arabic in ar/. */
  sourceDir: string;
  /** The assets directory wrangler publishes. Emptied first. */
  outDir: string;
  stylesheet: string;
}

/** Writes every page and returns the published paths. */
export function build(options: BuildOptions): string[] {
  rmSync(options.outDir, { recursive: true, force: true });
  const written: string[] = [];
  const write = (relative: string, content: string) => {
    const path = join(options.outDir, relative);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, content);
  };
  for (const locale of ["en", "ar"] as const) {
    for (const page of PAGES) {
      const source = join(
        options.sourceDir,
        locale === "en" ? "" : locale,
        page.file,
      );
      const markdown = readFileSync(source, "utf8");
      write(
        `${pagePath(locale, page.key).slice(1)}.html`,
        pageHtml(locale, page, markdown),
      );
      written.push(pagePath(locale, page.key));
    }
  }
  write("404.html", notFoundHtml());
  write("styles.css", readFileSync(options.stylesheet, "utf8"));
  // The app-link association files (app-links.ts), for app.studafy.com.
  write(".well-known/apple-app-site-association", appleAppSiteAssociation());
  write(".well-known/assetlinks.json", assetLinks());
  write("_headers", HEADERS);
  write("_redirects", REDIRECTS);
  return written;
}
