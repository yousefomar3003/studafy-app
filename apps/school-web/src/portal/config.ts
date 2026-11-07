/**
 * The School Portal's build settings (docs/deployment/studafy-web.md). The
 * Supabase key is the project's publishable key: it identifies the project
 * and grants nothing by itself.
 */
const env = import.meta.env as Record<string, string | undefined>;

export type Provider = "apple" | "google" | "azure";

function providers(value: string | undefined): Provider[] {
  const known: Provider[] = ["apple", "google", "azure"];
  return (value ?? "google,azure")
    .split(",")
    .map((item) => item.trim())
    .filter((item): item is Provider => known.includes(item as Provider));
}

export const portalConfig = {
  apiUrl: env.VITE_API_URL ?? "https://api.studafy.com",
  supabaseUrl: env.VITE_SUPABASE_URL ?? "",
  supabaseKey: env.VITE_SUPABASE_PUBLISHABLE_KEY ?? "",
  /** Only providers set up on the Supabase project show a button. */
  providers: providers(env.VITE_PORTAL_PROVIDERS),
  turnstileSiteKey: env.VITE_TURNSTILE_SITE_KEY ?? "",
  /** The public site, for the logo and the legal links. */
  siteUrl: env.VITE_SITE_URL ?? "https://studafy.com",
  /** A session left idle this long ends (plan 7.6). */
  idleLimitMs: 12 * 60 * 60 * 1000,
} as const;
