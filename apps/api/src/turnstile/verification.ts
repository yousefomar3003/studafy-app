/** No token, provider body or secret is ever logged or returned to a caller. */
export interface TurnstileOptions {
  secret: string;
  siteKey: string;
  hostnames: readonly string[];
}
export type SiteverifyFetch = (
  url: string,
  init: RequestInit,
) => Promise<Response>;
export async function verifyTurnstile(
  options: TurnstileOptions,
  token: unknown,
  fetcher: SiteverifyFetch = fetch,
): Promise<boolean> {
  if (
    typeof token !== "string" || !token.trim() || token.length > 2048 ||
    !options.secret || options.hostnames.length === 0
  ) return false;
  try {
    const response = await fetcher(
      "https://challenges.cloudflare.com/turnstile/v0/siteverify",
      {
        method: "POST",
        signal: AbortSignal.timeout(8000),
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ secret: options.secret, response: token }),
      },
    );
    if (!response.ok) return false;
    const result = await response.json() as Record<string, unknown>;
    return result.success === true && result.action === "student_lookup" &&
      typeof result.hostname === "string" &&
      options.hostnames.includes(result.hostname);
  } catch {
    return false;
  }
}
