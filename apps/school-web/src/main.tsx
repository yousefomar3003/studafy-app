import "@fontsource-variable/inter";
import "@fontsource/ibm-plex-sans-arabic/400.css";
import "@fontsource/ibm-plex-sans-arabic/500.css";
import "@fontsource/ibm-plex-sans-arabic/600.css";
import "@fontsource/ibm-plex-sans-arabic/700.css";
import "./styles/base.css";
import "./styles/sections.css";
import "./styles/pages.css";

import { StrictMode } from "react";
import { createRoot, hydrateRoot } from "react-dom/client";
import { App } from "./App";
import { type Lang, LANGS, type PageId, routeFor } from "./routes";

const LANGUAGE_KEY = "studafy.lang";

function savedLanguage(): Lang | null {
  try {
    const value = localStorage.getItem(LANGUAGE_KEY);
    return LANGS.includes(value as Lang) ? (value as Lang) : null;
  } catch {
    return null;
  }
}

function saveLanguage(lang: Lang) {
  try {
    localStorage.setItem(LANGUAGE_KEY, lang);
  } catch {
    // Private windows may refuse storage; the switch still works by link.
  }
}

/**
 * First visit to an English page from a browser set to Arabic: go to the
 * Arabic page once. A language picked with the switch is remembered and
 * always wins.
 */
function redirectToPreferredLanguage(lang: Lang): boolean {
  if (lang !== "en" || savedLanguage()) return false;
  const preferred = navigator.languages?.[0] ?? navigator.language ?? "";
  if (!preferred.toLowerCase().startsWith("ar")) return false;
  const path = location.pathname === "/" ? "" : location.pathname;
  location.replace(`/ar${path}${location.hash}`);
  return true;
}

document.addEventListener("click", (event) => {
  const link = (event.target as Element | null)?.closest<HTMLElement>(
    "[data-lang-switch]",
  );
  const lang = link?.dataset.langSwitch as Lang | undefined;
  if (lang && LANGS.includes(lang)) saveLanguage(lang);
});

const root = document.getElementById("root");
if (root) {
  const fromServer = root.dataset.page as PageId | undefined;
  const route = fromServer
    ? { page: fromServer, lang: (root.dataset.lang as Lang) ?? "en" }
    : routeFor(location.pathname);
  if (!redirectToPreferredLanguage(route.lang)) {
    const app = (
      <StrictMode>
        <App page={route.page} lang={route.lang} />
      </StrictMode>
    );
    if (fromServer) {
      hydrateRoot(root, app);
    } else {
      // The dev server serves the bare template: render from the address.
      document.documentElement.lang = route.lang;
      document.documentElement.dir = route.lang === "ar" ? "rtl" : "ltr";
      createRoot(root).render(app);
    }
  }
}
