import { createContext, useContext } from "react";
import { portalAr } from "./ar";
import { type PortalCopy, portalEn } from "./en";

export type PortalLang = "en" | "ar";
const KEY = "studafy.portal.lang";

export function copyFor(lang: PortalLang): PortalCopy {
  return lang === "ar" ? portalAr : portalEn;
}

/** The saved choice, else the browser's language. */
export function initialLang(): PortalLang {
  try {
    const saved = localStorage.getItem(KEY);
    if (saved === "en" || saved === "ar") return saved;
  } catch { /* blocked storage */ }
  return (navigator.languages?.[0] ?? navigator.language ?? "")
      .toLowerCase().startsWith("ar")
    ? "ar"
    : "en";
}

export function saveLang(lang: PortalLang): void {
  try {
    localStorage.setItem(KEY, lang);
  } catch { /* the choice lasts this visit only */ }
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
}

export const CopyContext = createContext<PortalCopy>(portalEn);
export const useCopy = (): PortalCopy => useContext(CopyContext);

/** The words for an API refusal code. */
export function errorText(copy: PortalCopy, code: string): string {
  return copy.errors[code] ?? copy.errors["generic"]!;
}

export type { PortalCopy } from "./en";
