/**
 * Build-time settings. Vite replaces `import.meta.env.VITE_*` in the browser
 * bundle; the prerender script runs under Bun, which reads the same names
 * from the environment, so both halves of a page agree.
 */
const env = import.meta.env as Record<string, string | undefined>;

function optionalUrl(value: string | undefined): string | null {
  const trimmed = value?.trim();
  return trimmed && trimmed.startsWith("https://") ? trimmed : null;
}

export const config = {
  /** The public site's own address, for canonical and share links. */
  siteUrl: optionalUrl(env.VITE_SITE_URL) ?? "https://studafy.com",
  /** Where "Open the School Portal" goes. */
  portalUrl: optionalUrl(env.VITE_PORTAL_URL) ?? "https://school.studafy.com",
  /**
   * The School Portal page, its menu link and every sign-in button stay
   * hidden until the portal passes its release gate (plan section 11).
   */
  portalPublic: env.VITE_PORTAL_PUBLIC === "true",
  /** Store pages. Until both are set, the site says "coming soon". */
  appStoreUrl: optionalUrl(env.VITE_APP_STORE_URL),
  playStoreUrl: optionalUrl(env.VITE_PLAY_STORE_URL),
  contactEmail: "hello@studafy.com",
} as const;

/** The legal site's page in the reader's language (`/ar/...` for Arabic). */
export function legalUrl(page: "privacy" | "terms", lang: "en" | "ar"): string {
  return `https://legal.studafy.com${lang === "ar" ? "/ar" : ""}/${page}`;
}
