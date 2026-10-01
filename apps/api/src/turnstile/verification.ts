/** No token, provider body or secret is ever logged or returned to a caller. */
export interface TurnstileOptions {
  secret: string;
  siteKey: string;
  hostnames: readonly string[];
  /**
   * Accept Cloudflare's published testing keys (`1x0000…`). Their siteverify
   * answer carries no `action`, so without this every test-key solve was
   * refused and a parent could never link a child in development. Never set
   * in production: there only a real widget's result counts.
   */
  allowTestingKeys?: boolean;
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
    const hostnameAllowed = typeof result.hostname === "string" &&
      options.hostnames.includes(result.hostname);
    const metadata = result.metadata as Record<string, unknown> | undefined;
    if (metadata?.result_with_testing_key === true) {
      // A testing key's answer names no action. It is accepted only where the
      // deployment opted in, and still only on an allowlisted hostname.
      return options.allowTestingKeys === true && result.success === true &&
        hostnameAllowed;
    }
    return result.success === true && result.action === "student_lookup" &&
      hostnameAllowed;
  } catch {
    return false;
  }
}
