import { isIP } from "node:net";
import { lookup } from "node:dns/promises";
import type { EnvironmentType } from "@studafy/config";

export class SafeFetchError extends Error {
  readonly code:
    | "URL_REJECTED"
    | "ADDRESS_REJECTED"
    | "REDIRECT_REJECTED"
    | "RESPONSE_TOO_LARGE"
    | "UPSTREAM_TIMEOUT";

  constructor(code: SafeFetchError["code"]) {
    super(code);
    this.name = "SafeFetchError";
    this.code = code;
  }
}

export interface ResolvedAddress {
  address: string;
  family: number;
}

export interface SafeProviderClientOptions {
  origins: readonly string[];
  environment: EnvironmentType;
  fetchImpl?: typeof fetch;
  resolve?: (hostname: string) => Promise<ResolvedAddress[]>;
  timeoutMs?: number;
  maxResponseBytes?: number;
  maxRedirects?: number;
}

function ipv4Number(address: string): number | null {
  const parts = address.split(".").map(Number);
  if (
    parts.length !== 4 ||
    parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)
  ) return null;
  return (((parts[0]! << 24) >>> 0) + (parts[1]! << 16) + (parts[2]! << 8) +
    parts[3]!) >>> 0;
}

function inV4Range(value: number, base: number, prefix: number): boolean {
  const mask = prefix === 0 ? 0 : (0xffffffff << (32 - prefix)) >>> 0;
  return (value & mask) === (base & mask);
}

const BLOCKED_V4_RANGES = [
  ["0.0.0.0", 8],
  ["10.0.0.0", 8],
  ["100.64.0.0", 10],
  ["127.0.0.0", 8],
  ["169.254.0.0", 16],
  ["172.16.0.0", 12],
  ["192.0.0.0", 24],
  ["192.0.2.0", 24],
  ["192.168.0.0", 16],
  ["198.18.0.0", 15],
  ["198.51.100.0", 24],
  ["203.0.113.0", 24],
  ["224.0.0.0", 4],
  ["240.0.0.0", 4],
] as const;

function isBlockedIpv4Number(value: number): boolean {
  return BLOCKED_V4_RANGES.some(([base, prefix]) =>
    inV4Range(value, ipv4Number(base)!, prefix)
  );
}

function mappedIpv4Number(address: string): number | null {
  const halves = address.split("::");
  if (halves.length > 2) return null;
  const left = halves[0] ? halves[0].split(":") : [];
  const right = halves.length === 2 && halves[1] ? halves[1].split(":") : [];
  const missing = halves.length === 2 ? 8 - left.length - right.length : 0;
  const groups = [...left, ...Array(Math.max(0, missing)).fill("0"), ...right];
  if (
    groups.length !== 8 ||
    groups.some((group) => !/^[0-9a-f]{1,4}$/.test(group))
  ) return null;
  const values = groups.map((group) => Number.parseInt(group, 16));
  if (
    values.slice(0, 5).some((group) => group !== 0) || values[5] !== 0xffff
  ) return null;
  return ((values[6]! << 16) | values[7]!) >>> 0;
}

export function isBlockedAddress(address: string): boolean {
  const normalized = address.toLowerCase().split("%", 1)[0]!;
  const v4 = ipv4Number(normalized);
  if (v4 !== null) return isBlockedIpv4Number(v4);
  if (isIP(normalized) !== 6) return true;
  if (normalized === "::" || normalized === "::1") return true;
  if (/^f[cd]/.test(normalized)) return true;
  if (/^fe[89ab]/.test(normalized)) return true;
  if (/^ff/.test(normalized)) return true;
  const mapped = normalized.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped?.[1]) return isBlockedAddress(mapped[1]);
  const mappedNumber = mappedIpv4Number(normalized);
  return mappedNumber !== null && isBlockedIpv4Number(mappedNumber);
}

function normalizeOrigin(value: string, environment: EnvironmentType): string {
  const url = new URL(value);
  if (
    url.username || url.password || url.pathname !== "/" || url.search ||
    url.hash
  ) {
    throw new SafeFetchError("URL_REJECTED");
  }
  if (environment === "production" && url.protocol !== "https:") {
    throw new SafeFetchError("URL_REJECTED");
  }
  if (url.protocol !== "https:" && url.protocol !== "http:") {
    throw new SafeFetchError("URL_REJECTED");
  }
  return url.origin;
}

async function defaultResolve(hostname: string): Promise<ResolvedAddress[]> {
  return await lookup(hostname, { all: true, verbatim: true });
}

function combinedSignal(
  parent: AbortSignal | undefined,
  timeoutMs: number,
): { signal: AbortSignal; clear: () => void } {
  const controller = new AbortController();
  const abort = () => controller.abort();
  parent?.addEventListener("abort", abort, { once: true });
  if (parent?.aborted) abort();
  const timer = setTimeout(abort, timeoutMs);
  return {
    signal: controller.signal,
    clear: () => {
      clearTimeout(timer);
      parent?.removeEventListener("abort", abort);
    },
  };
}

/** Fetches only reviewed provider origins and validates every redirect hop. */
export class SafeProviderClient {
  readonly #origins: Set<string>;
  readonly #fetch: typeof fetch;
  readonly #resolve: (hostname: string) => Promise<ResolvedAddress[]>;
  readonly #timeoutMs: number;
  readonly #maxResponseBytes: number;
  readonly #maxRedirects: number;

  constructor(options: SafeProviderClientOptions) {
    this.#origins = new Set(
      options.origins.map((origin) =>
        normalizeOrigin(origin, options.environment)
      ),
    );
    if (this.#origins.size === 0) throw new SafeFetchError("URL_REJECTED");
    this.#fetch = options.fetchImpl ?? fetch;
    this.#resolve = options.resolve ?? defaultResolve;
    this.#timeoutMs = options.timeoutMs ?? 5_000;
    this.#maxResponseBytes = options.maxResponseBytes ?? 1024 * 1024;
    this.#maxRedirects = options.maxRedirects ?? 3;
  }

  async fetch(
    relativePath: string,
    init: RequestInit = {},
    parentSignal?: AbortSignal,
  ): Promise<Response> {
    if (!relativePath.startsWith("/") || relativePath.startsWith("//")) {
      throw new SafeFetchError("URL_REJECTED");
    }
    const origin = this.#origins.values().next().value as string;
    let url = new URL(relativePath, origin);
    const deadline = combinedSignal(parentSignal, this.#timeoutMs);
    try {
      for (let redirects = 0;; redirects += 1) {
        await this.#validate(url);
        let response: Response;
        try {
          response = await this.#fetch(url, {
            ...init,
            redirect: "manual",
            signal: deadline.signal,
          });
        } catch {
          if (deadline.signal.aborted) {
            throw new SafeFetchError("UPSTREAM_TIMEOUT");
          }
          throw new SafeFetchError("URL_REJECTED");
        }
        if ([301, 302, 303, 307, 308].includes(response.status)) {
          if (redirects >= this.#maxRedirects) {
            throw new SafeFetchError("REDIRECT_REJECTED");
          }
          const location = response.headers.get("location");
          if (!location) throw new SafeFetchError("REDIRECT_REJECTED");
          url = new URL(location, url);
          continue;
        }
        return await this.#boundedResponse(response);
      }
    } finally {
      deadline.clear();
    }
  }

  async #validate(url: URL): Promise<void> {
    if (
      url.username || url.password || url.hash || !this.#origins.has(url.origin)
    ) {
      throw new SafeFetchError("URL_REJECTED");
    }
    const hostname = url.hostname.replace(/^\[|\]$/g, "");
    if (isIP(hostname) !== 0) throw new SafeFetchError("ADDRESS_REJECTED");
    const addresses = await this.#resolve(hostname);
    if (
      addresses.length === 0 ||
      addresses.some((entry) => isBlockedAddress(entry.address))
    ) {
      throw new SafeFetchError("ADDRESS_REJECTED");
    }
  }

  async #boundedResponse(response: Response): Promise<Response> {
    const declared = Number(response.headers.get("content-length"));
    if (Number.isFinite(declared) && declared > this.#maxResponseBytes) {
      throw new SafeFetchError("RESPONSE_TOO_LARGE");
    }
    if (!response.body) return response;
    const reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > this.#maxResponseBytes) {
        await reader.cancel();
        throw new SafeFetchError("RESPONSE_TOO_LARGE");
      }
      chunks.push(value);
    }
    const body = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      body.set(chunk, offset);
      offset += chunk.byteLength;
    }
    const headers = new Headers(response.headers);
    headers.set("content-length", String(size));
    return new Response(body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  }
}
