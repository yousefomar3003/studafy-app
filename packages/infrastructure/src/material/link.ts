/**
 * Fetching a link a teacher put on a lesson (ADR-0037).
 *
 * The address is a teacher's, so it is treated as untrusted:
 *  - https on port 443 only, no credentials in the URL;
 *  - every address the name resolves to must be public - never loopback,
 *    private, link-local, carrier-grade NAT, multicast, the cloud metadata
 *    range or an IPv6 unique-local or mapped private address - checked
 *    again on each of at most three redirects;
 *  - no cookies, no auth headers, a short timeout and a byte cap;
 *  - only web pages, plain text and PDFs are read.
 * What cannot be read says why, so the helper never claims to have read it.
 *
 * Known limit: the check resolves the name before the request does, so a
 * name that changes its answer between the two (DNS rebinding) is not
 * caught here; the worker's network has no route to anything internal
 * worth reaching beyond what the address check covers.
 */
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";

export type LinkFailure =
  | "link_blocked_address"
  | "link_unreachable"
  | "link_needs_sign_in"
  | "link_not_found"
  | "link_unsupported_type"
  | "link_too_large"
  | "link_video";

export type LinkFetch =
  | {
    ok: true;
    url: string;
    contentType: string;
    bytes: Uint8Array;
    truncated: boolean;
  }
  | { ok: false; reason: LinkFailure };

export type Resolver = (host: string) => Promise<string[]>;

const defaultResolver: Resolver = async (host) =>
  (await lookup(host, { all: true, verbatim: true })).map((entry) =>
    entry.address
  );

function ipv4Private(address: string): boolean {
  const [a, b, c] = address.split(".").map(Number) as [
    number,
    number,
    number,
    number,
  ];
  return a === 0 || a === 10 || a === 127 || a >= 224 ||
    (a === 100 && b >= 64 && b <= 127) ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 168) ||
    (a === 192 && b === 0 && (c === 0 || c === 2)) ||
    (a === 198 && (b === 18 || b === 19)) ||
    (a === 198 && b === 51 && c === 100) ||
    (a === 203 && b === 0 && c === 113);
}

/** True for any address a request must never go to. */
export function isBlockedAddress(address: string): boolean {
  const version = isIP(address);
  if (version === 4) return ipv4Private(address);
  if (version !== 6) return true;
  const lower = address.toLowerCase();
  const mapped = lower.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped) return ipv4Private(mapped[1]!);
  if (lower === "::" || lower === "::1") return true;
  const first = parseInt(lower.split(":")[0] || "0", 16);
  return (first & 0xfe00) === 0xfc00 || // fc00::/7 unique local (Fly's 6PN)
    (first & 0xffc0) === 0xfe80 || // fe80::/10 link local
    (first & 0xff00) === 0xff00 || // multicast
    lower.startsWith("64:ff9b:") || // NAT64 can reach IPv4 private space
    lower.startsWith("2001:db8:") ||
    lower.startsWith("::ffff:") || lower.startsWith("::");
}

const VIDEO_HOSTS = /(^|\.)(youtube\.com|youtu\.be|vimeo\.com|tiktok\.com)$/i;
const SIGN_IN_HOSTS =
  /(^|\.)(accounts\.google\.com|login\.microsoftonline\.com|login\.live\.com|classroom\.google\.com|teams\.microsoft\.com)$/i;
const READABLE =
  /^(text\/html|application\/xhtml\+xml|text\/plain|application\/pdf)\b/i;

async function checkUrl(
  raw: string,
  resolve: Resolver,
): Promise<URL | LinkFailure> {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return "link_unreachable";
  }
  if (url.protocol !== "https:" || url.username || url.password) {
    return "link_blocked_address";
  }
  if (url.port && url.port !== "443") return "link_blocked_address";
  const host = url.hostname.replace(/^\[|\]$/g, "");
  if (VIDEO_HOSTS.test(host)) return "link_video";
  if (SIGN_IN_HOSTS.test(host)) return "link_needs_sign_in";
  if (
    /^(localhost|.*\.local|.*\.internal|.*\.fly\.dev\.internal)$/i.test(host)
  ) {
    return "link_blocked_address";
  }
  let addresses: string[];
  try {
    addresses = isIP(host) ? [host] : await resolve(host);
  } catch {
    return "link_unreachable";
  }
  if (addresses.length === 0 || addresses.some(isBlockedAddress)) {
    return "link_blocked_address";
  }
  return url;
}

export async function fetchPublicLink(
  raw: string,
  options: {
    maxBytes: number;
    timeoutMs?: number;
    resolve?: Resolver;
    fetchImpl?: typeof fetch;
  },
): Promise<LinkFetch> {
  const resolve = options.resolve ?? defaultResolver;
  const fetchImpl = options.fetchImpl ?? fetch;
  let current = raw;
  for (let hop = 0; hop <= 3; hop++) {
    const checked = await checkUrl(current, resolve);
    if (typeof checked === "string") return { ok: false, reason: checked };
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      options.timeoutMs ?? 10_000,
    );
    let response: Response;
    try {
      response = await fetchImpl(checked, {
        redirect: "manual",
        signal: controller.signal,
        headers: {
          "user-agent": "StudafyLessonReader/1.0",
          accept:
            "text/html,application/xhtml+xml,text/plain,application/pdf;q=0.9",
        },
      });
    } catch {
      clearTimeout(timer);
      return { ok: false, reason: "link_unreachable" };
    }
    if (response.status >= 300 && response.status < 400) {
      clearTimeout(timer);
      const next = response.headers.get("location");
      if (!next) return { ok: false, reason: "link_unreachable" };
      current = new URL(next, checked).toString();
      continue;
    }
    if (response.status === 401 || response.status === 403) {
      clearTimeout(timer);
      return { ok: false, reason: "link_needs_sign_in" };
    }
    if (response.status === 404 || response.status === 410) {
      clearTimeout(timer);
      return { ok: false, reason: "link_not_found" };
    }
    if (!response.ok || !response.body) {
      clearTimeout(timer);
      return { ok: false, reason: "link_unreachable" };
    }
    const contentType = response.headers.get("content-type") ?? "";
    if (!READABLE.test(contentType)) {
      clearTimeout(timer);
      await response.body.cancel().catch(() => {});
      return {
        ok: false,
        reason: /^video\//i.test(contentType)
          ? "link_video"
          : "link_unsupported_type",
      };
    }
    const parts: Uint8Array[] = [];
    let size = 0;
    let truncated = false;
    const reader = response.body.getReader();
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        if (size + value.length > options.maxBytes) {
          parts.push(value.subarray(0, options.maxBytes - size));
          size = options.maxBytes;
          truncated = true;
          await reader.cancel().catch(() => {});
          break;
        }
        parts.push(value);
        size += value.length;
      }
    } catch {
      return { ok: false, reason: "link_unreachable" };
    } finally {
      clearTimeout(timer);
    }
    const bytes = new Uint8Array(size);
    let at = 0;
    for (const part of parts) {
      bytes.set(part, at);
      at += part.length;
    }
    return { ok: true, url: checked.toString(), contentType, bytes, truncated };
  }
  return { ok: false, reason: "link_unreachable" };
}
