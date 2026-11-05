import type { ReactNode } from "react";
import { config, legalUrl } from "../config";
import type { Copy } from "../i18n";
import { type Lang, type PageId, pathFor, publishedPages } from "../routes";

type MenuPage = Exclude<PageId, "notFound" | "home">;

function menuPages(): MenuPage[] {
  return publishedPages().filter((page): page is MenuPage => page !== "home");
}

function label(copy: Copy, page: MenuPage): string {
  return copy.nav[page];
}

/** The same page in the other language (home for the 404 page). */
function otherLanguageHref(page: PageId, lang: Lang): string {
  const other: Lang = lang === "en" ? "ar" : "en";
  return pathFor(page === "notFound" ? "home" : page, other);
}

function Header(
  { copy, lang, page }: { copy: Copy; lang: Lang; page: PageId },
) {
  const other: Lang = lang === "en" ? "ar" : "en";
  const links = menuPages().map((item) => (
    <a
      key={item}
      href={pathFor(item, lang)}
      aria-current={item === page ? "page" : undefined}
    >
      {label(copy, item)}
    </a>
  ));
  const language = (
    <a
      className="lang"
      href={otherLanguageHref(page, lang)}
      hrefLang={other}
      lang={other}
      data-lang-switch={other}
    >
      {copy.nav.otherLanguageName}
    </a>
  );
  return (
    <header className="site-header">
      <div className="wrap bar">
        <a className="logo" href={pathFor("home", lang)} aria-label="Studafy">
          <img src="/brand/logo.svg" alt="" width={120} height={37} />
        </a>
        <nav className="nav" aria-label={copy.nav.menu}>{links}</nav>
        <div className="bar-end">
          {language}
          <a className="button small" href={`${pathFor("home", lang)}#get`}>
            {copy.nav.getApp}
          </a>
          <details className="menu">
            <summary aria-label={copy.nav.menu}>
              <span className="burger" aria-hidden="true" />
            </summary>
            <nav className="menu-panel" aria-label={copy.nav.menu}>
              <a href={pathFor("home", lang)}>{copy.nav.home}</a>
              {links}
              {language}
            </nav>
          </details>
        </div>
      </div>
    </header>
  );
}

function Footer({ copy, lang }: { copy: Copy; lang: Lang }) {
  const year = new Date().getFullYear();
  return (
    <footer className="site-footer">
      <div className="wrap footer-grid">
        <div className="footer-brand">
          <img
            src="/brand/logo-white.svg"
            alt="Studafy"
            width={120}
            height={37}
          />
          <p>{copy.footer.tagline}</p>
        </div>
        <nav aria-label={copy.footer.product}>
          <h2>{copy.footer.product}</h2>
          <a href={pathFor("features", lang)}>{copy.nav.features}</a>
          {config.portalPublic && (
            <a href={pathFor("schools", lang)}>{copy.nav.schools}</a>
          )}
          <a href={`${pathFor("home", lang)}#get`}>{copy.nav.getApp}</a>
        </nav>
        <nav aria-label={copy.footer.company}>
          <h2>{copy.footer.company}</h2>
          <a href={pathFor("about", lang)}>{copy.nav.about}</a>
          <a href={pathFor("contact", lang)}>{copy.nav.contact}</a>
          <a href={`mailto:${config.contactEmail}`}>{config.contactEmail}</a>
        </nav>
        <nav aria-label={copy.footer.legal}>
          <h2>{copy.footer.legal}</h2>
          <a href={legalUrl("privacy", lang)}>{copy.footer.privacy}</a>
          <a href={legalUrl("terms", lang)}>{copy.footer.terms}</a>
        </nav>
      </div>
      <div className="wrap footer-base">
        <p>© {year} Studafy. {copy.footer.rights}</p>
        <a
          className="lang"
          href={pathFor("home", lang === "en" ? "ar" : "en")}
          data-lang-switch={lang === "en" ? "ar" : "en"}
        >
          {copy.nav.otherLanguageName}
        </a>
      </div>
    </footer>
  );
}

export function Layout(
  { copy, lang, page, children }: {
    copy: Copy;
    lang: Lang;
    page: PageId;
    children: ReactNode;
  },
) {
  return (
    <>
      <a className="skip" href="#main">{copy.nav.skip}</a>
      <Header copy={copy} lang={lang} page={page} />
      <main id="main">{children}</main>
      <Footer copy={copy} lang={lang} />
    </>
  );
}
