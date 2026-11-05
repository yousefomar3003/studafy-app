import { config } from "./config";

export type Lang = "en" | "ar";
export type PageId =
  | "home"
  | "features"
  | "schools"
  | "about"
  | "contact"
  | "notFound";

export const LANGS: readonly Lang[] = ["en", "ar"];

/** Each page's path in English; Arabic adds `/ar` in front. */
const PATHS: Record<Exclude<PageId, "notFound">, string> = {
  home: "/",
  features: "/features",
  schools: "/schools",
  about: "/about",
  contact: "/contact",
};

export function isPagePublished(page: PageId): boolean {
  return page !== "schools" || config.portalPublic;
}

/** The pages written to disk at build time, in menu order. */
export function publishedPages(): Exclude<PageId, "notFound">[] {
  return (Object.keys(PATHS) as Exclude<PageId, "notFound">[]).filter(
    isPagePublished,
  );
}

export function pathFor(page: Exclude<PageId, "notFound">, lang: Lang): string {
  const path = PATHS[page];
  if (lang === "en") return path;
  return path === "/" ? "/ar" : `/ar${path}`;
}

export function dirFor(lang: Lang): "ltr" | "rtl" {
  return lang === "ar" ? "rtl" : "ltr";
}

/** Reads a URL path back into a page and language (for the dev server). */
export function routeFor(pathname: string): { page: PageId; lang: Lang } {
  const clean = pathname.replace(/\/+$/, "") || "/";
  const lang: Lang = clean === "/ar" || clean.startsWith("/ar/") ? "ar" : "en";
  for (const page of publishedPages()) {
    if (pathFor(page, lang) === clean) return { page, lang };
  }
  return { page: "notFound", lang };
}
