import { describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  ANDROID_SHA256,
  APP_ID,
  APPLE_TEAM_ID,
  appLinksPending,
  CALLBACK_PATH,
} from "../src/app-links.ts";
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

describe("app-link association files (app.studafy.com)", () => {
  const repo = join(root, "..", "..");
  const source = (path: string) => readFileSync(join(repo, path), "utf8");
  const host = "app.studafy.com";

  test("apple-app-site-association claims only the callback, for the app", () => {
    const aasa = JSON.parse(read(".well-known/apple-app-site-association"));
    expect(aasa).toEqual({
      applinks: {
        details: [
          {
            appIDs: [`${APPLE_TEAM_ID}.com.studafy.light`],
            components: [
              { "/": "/auth/callback" },
              { "/": "/auth/callback/*" },
            ],
          },
        ],
      },
    });
    expect(read("_headers")).toMatch(
      /\/\.well-known\/apple-app-site-association\n\s+Content-Type: application\/json/,
    );
  });

  test("assetlinks.json names the package and one signing fingerprint", () => {
    expect(JSON.parse(read(".well-known/assetlinks.json"))).toEqual([
      {
        relation: ["delegate_permission/common.handle_all_urls"],
        target: {
          namespace: "android_app",
          package_name: "com.studafy.light",
          sha256_cert_fingerprints: [ANDROID_SHA256],
        },
      },
    ]);
  });

  test("identifiers are real values or clearly marked placeholders", () => {
    expect(APPLE_TEAM_ID).toMatch(/^(PENDING_[A-Z_]+|[A-Z0-9]{10})$/);
    expect(ANDROID_SHA256).toMatch(
      /^(PENDING_[A-Z0-9_]+|([0-9A-F]{2}:){31}[0-9A-F]{2})$/,
    );
    expect(appLinksPending()).toBe(
      APPLE_TEAM_ID.startsWith("PENDING") ||
        ANDROID_SHA256.startsWith("PENDING"),
    );
  });

  test("the app, its manifests and Supabase claim the same domain and path", () => {
    const callback = `https://${host}${CALLBACK_PATH}`;
    expect(source("lib/features/session/domain/auth_callback.dart"))
      .toContain(`'${callback}'`);
    const manifest = source("android/app/src/main/AndroidManifest.xml");
    expect(manifest).toContain(`android:host="${host}"`);
    expect(manifest).toContain(`android:pathPrefix="${CALLBACK_PATH}"`);
    expect(source("android/app/build.gradle.kts")).toContain(
      `applicationId = "${APP_ID}"`,
    );
    expect(source("ios/Runner/Runner.entitlements")).toContain(
      `<string>applinks:${host}</string>`,
    );
    expect(source("supabase/config.toml")).toContain(`"${callback}"`);
  });

  test("the Worker answers on the legal and app hosts, and on workers.dev", () => {
    const toml = source("ops/legal-site/wrangler.toml");
    const routes = toml.split("\n").find((l) => l.startsWith("routes"));
    expect(routes).toContain(
      '{ pattern = "legal.studafy.com", custom_domain = true }',
    );
    expect(routes).toContain(`{ pattern = "${host}", custom_domain = true }`);
    expect(toml).toMatch(/^workers_dev = true$/m);
  });
});
