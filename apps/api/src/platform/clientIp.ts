/**
 * Where a request's client address comes from (security audit 2026-10-08).
 *
 * The address keys the pre-auth rate limits and the access log's `ip_hash`,
 * so it must come from something a client cannot write. Before this module
 * production trusted `CF-Connecting-IP` from anyone, and every other
 * environment trusted the first `X-Forwarded-For` entry. Both are request
 * headers: a caller reaching the Fly origin directly (`*.fly.dev`, or the
 * app's own IPs) could name any address per request and so never meet an
 * IP-keyed limit.
 *
 * The sources:
 *  - `fly`: `Fly-Client-IP`, which Fly's proxy always sets to the address it
 *    accepted the connection from; a client cannot supply it.
 *  - `cloudflare`: `CF-Connecting-IP`, but only when the connection Fly saw
 *    (`Fly-Client-IP`) came from one of Cloudflare's published ranges.
 *    Anything else is a direct origin request and keys on its real peer.
 *  - `forwarded`: the first `X-Forwarded-For` entry, then
 *    `CF-Connecting-IP`. Local development and tests only; production
 *    refuses it.
 */
import { isIP } from "node:net";

export type ClientIpSource = "fly" | "cloudflare" | "forwarded";

type HeaderReader = (name: string) => string | undefined;

/**
 * Cloudflare's published edge ranges (https://www.cloudflare.com/ips/,
 * fetched 2026-10-08). They change rarely; a stale list fails safe, since a
 * new Cloudflare range is then keyed on its edge address, not trusted.
 */
export const CLOUDFLARE_RANGES: readonly string[] = [
  "173.245.48.0/20",
  "103.21.244.0/22",
  "103.22.200.0/22",
  "103.31.4.0/22",
  "141.101.64.0/18",
  "108.162.192.0/18",
  "190.93.240.0/20",
  "188.114.96.0/20",
  "197.234.240.0/22",
  "198.41.128.0/17",
  "162.158.0.0/15",
  "104.16.0.0/13",
  "104.24.0.0/14",
  "172.64.0.0/13",
  "131.0.72.0/22",
  "2400:cb00::/32",
  "2606:4700::/32",
  "2803:f800::/32",
  "2405:b500::/32",
  "2405:8100::/32",
  "2a06:98c0::/29",
  "2c0f:f248::/32",
];

/** The address as a big-endian bit string's integer, or null. */
function addressValue(
  address: string,
): { bits: 32 | 128; value: bigint } | null {
  let text = address.trim().toLowerCase();
  const mapped = text.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped?.[1]) text = mapped[1];
  const version = isIP(text);
  if (version === 4) {
    const value = text.split(".").reduce(
      (n, part) => (n << 8n) + BigInt(Number(part)),
      0n,
    );
    return { bits: 32, value };
  }
  if (version !== 6) return null;
  const [head = "", tail = ""] = text.split("::");
  const headParts = head ? head.split(":") : [];
  const tailParts = tail ? tail.split(":") : [];
  const zeros = text.includes("::")
    ? 8 - headParts.length - tailParts.length
    : 0;
  const groups = [
    ...headParts,
    ...Array<string>(zeros).fill("0"),
    ...tailParts,
  ];
  if (groups.length !== 8) return null;
  const value = groups.reduce(
    (n, group) => (n << 16n) + BigInt(parseInt(group || "0", 16)),
    0n,
  );
  return { bits: 128, value };
}

const PARSED_RANGES = CLOUDFLARE_RANGES.map((range) => {
  const [base = "", length = "0"] = range.split("/");
  const parsed = addressValue(base)!;
  const prefix = BigInt(Number(length));
  const shift = BigInt(parsed.bits) - prefix;
  return { bits: parsed.bits, network: parsed.value >> shift, shift };
});

/** True when [address] is inside one of Cloudflare's edge ranges. */
export function isCloudflareAddress(address: string | undefined): boolean {
  if (!address) return false;
  const parsed = addressValue(address);
  if (!parsed) return false;
  return PARSED_RANGES.some((range) =>
    range.bits === parsed.bits &&
    parsed.value >> range.shift === range.network
  );
}

/** True when the request reached the origin through Cloudflare. */
export function viaCloudflare(header: HeaderReader): boolean {
  return isCloudflareAddress(header("fly-client-ip"));
}

/** The client address for [source], or null when none can be trusted. */
export function resolveClientAddress(
  source: ClientIpSource,
  header: HeaderReader,
): string | null {
  const fly = header("fly-client-ip")?.trim() || null;
  switch (source) {
    case "fly":
      return fly;
    case "cloudflare": {
      if (fly && isCloudflareAddress(fly)) {
        return header("cf-connecting-ip")?.trim() || null;
      }
      // A direct origin request: its real peer, never what it claims.
      return fly;
    }
    case "forwarded":
      return header("x-forwarded-for")?.split(",")[0]?.trim() ||
        header("cf-connecting-ip")?.trim() || null;
  }
}
