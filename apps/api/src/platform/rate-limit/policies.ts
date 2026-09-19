/**
 * OPS-060 rate-limit policy registry.
 *
 * Every /v1 flow maps to exactly one flow policy here. The registry is the
 * single source of truth for both the middleware (which consumes it) and the
 * operator-facing catalogue (docs/security/rate-limit-catalogue.md), so a
 * drift test can prove the two never diverge.
 *
 * Subject scoping: "ip" limits are keyed by a normalized client network
 * prefix (never the raw address - a /64 aggregate for IPv6, the address for
 * IPv4), "account" and "tenant" by HMAC digests. Raw identifiers are never
 * written into Redis keys, so the key namespace itself is not an
 * enumeration side channel.
 */
import { createHmac } from "node:crypto";
import type {
  RateLimitPolicy,
  SlidingWindowPolicy,
  TokenBucketPolicy,
} from "@studafy/infrastructure";

export type RateLimitFlow =
  | "auth"
  | "registration"
  | "passwordReset"
  | "verification"
  | "rpc"
  | "linking"
  | "uploadIntent"
  | "search"
  | "publicDefault"
  | "authenticatedApi"
  | "adminApi"
  | "billingPurchase"
  | "storeWebhook";

export interface FlowPolicy {
  flow: RateLimitFlow;
  subject: "ip" | "account" | "tenant";
  policy: RateLimitPolicy;
  /**
   * True when a Redis failure must fail closed (503 SERVICE_UNAVAILABLE) -
   * flows protecting credentials, money, harm, or scarce resources. The only
   * fail-open flows are cheap ordinary reads, which degrade to a bounded
   * in-process cap instead of blocking users.
   */
  failClosed: boolean;
  /** Human-readable rationale, surfaced in the operator catalogue. */
  rationale: string;
}

/**
 * Session-lifecycle and account mutations. Login itself is Supabase-side;
 * this flow covers the /v1 session routes an authenticated-but-abused
 * session could otherwise churn (device revocation, identity linking,
 * reauth grants).
 */
const AUTH_FLOW: SlidingWindowPolicy = {
  kind: "slidingWindow",
  limit: 30,
  windowSeconds: 300,
};

export const RATE_LIMIT_FLOWS: Record<RateLimitFlow, FlowPolicy> = {
  auth: {
    flow: "auth",
    subject: "account",
    policy: AUTH_FLOW,
    failClosed: true,
    rationale:
      "Session lifecycle mutations: an abused session must not churn grants or revocations.",
  },
  registration: {
    flow: "registration",
    subject: "ip",
    policy: { kind: "slidingWindow", limit: 5, windowSeconds: 3600 },
    failClosed: true,
    rationale:
      "Account creation is Supabase-side today; the policy is declared so the edge rule and the future /v1 surface agree.",
  },
  passwordReset: {
    flow: "passwordReset",
    subject: "ip",
    policy: { kind: "slidingWindow", limit: 5, windowSeconds: 3600 },
    failClosed: true,
    rationale:
      "Password reset mail is a harassment and enumeration vector; declared for the Supabase-side gateway rule.",
  },
  verification: {
    flow: "verification",
    subject: "ip",
    policy: { kind: "slidingWindow", limit: 10, windowSeconds: 3600 },
    failClosed: true,
    rationale:
      "Verification-code sends are costed and abusable; declared for the Supabase-side gateway rule.",
  },
  rpc: {
    flow: "rpc",
    subject: "account",
    policy: { kind: "fixedWindow", limit: 60, windowSeconds: 300 },
    failClosed: true,
    rationale:
      "The two public PostgREST RPCs (consent, notification read state) bypass Hono; the /v1 equivalents enforce the same budget and the edge rule covers the raw path.",
  },
  linking: {
    flow: "linking",
    subject: "account",
    policy: { kind: "slidingWindow", limit: 20, windowSeconds: 300 },
    failClosed: true,
    rationale:
      "Student locate and guardian linking probe exact names/codes; enumeration must be bounded and fail closed.",
  },
  uploadIntent: {
    flow: "uploadIntent",
    subject: "account",
    policy: { kind: "fixedWindow", limit: 100, windowSeconds: 3600 },
    failClosed: true,
    rationale:
      "Storage intents cost egress and storage; enforcement lands with FILE-051's owning route.",
  },
  search: {
    flow: "search",
    subject: "account",
    policy: { kind: "slidingWindow", limit: 60, windowSeconds: 300 },
    failClosed: true,
    rationale:
      "Full-text search is the most expensive read; enforcement lands with ARC-011's owning route.",
  },
  publicDefault: {
    flow: "publicDefault",
    subject: "ip",
    policy: { kind: "fixedWindow", limit: 120, windowSeconds: 60 },
    failClosed: false,
    rationale:
      "Pre-auth edge backstop per network prefix; fail-open with a bounded in-process cap so a Redis outage cannot take the whole surface down.",
  },
  authenticatedApi: {
    flow: "authenticatedApi",
    subject: "account",
    policy: { kind: "tokenBucket", limit: 300, windowSeconds: 300, burst: 150 },
    failClosed: false,
    rationale:
      "Ordinary authenticated traffic, burst-tolerant, with a per-tenant ceiling; fail-open with a bounded in-process cap.",
  },
  adminApi: {
    flow: "adminApi",
    subject: "account",
    policy: { kind: "slidingWindow", limit: 120, windowSeconds: 300 },
    failClosed: true,
    rationale:
      "School-admin and internal operations mutate many records at once; fail closed rather than risk unbounded fan-out.",
  },
  billingPurchase: {
    flow: "billingPurchase",
    subject: "account",
    policy: { kind: "fixedWindow", limit: 20, windowSeconds: 3600 },
    failClosed: true,
    rationale:
      "Purchase, restore and parental challenges require a fail-closed account budget.",
  },
  storeWebhook: {
    flow: "storeWebhook",
    subject: "ip",
    policy: { kind: "fixedWindow", limit: 600, windowSeconds: 60 },
    failClosed: true,
    rationale:
      "Store webhook verification has a separate fail-closed IP budget.",
  },
};

/** Per-tenant ceiling shared by every account in one school. */
export const TENANT_CEILING: TokenBucketPolicy = {
  kind: "tokenBucket",
  limit: 2000,
  windowSeconds: 300,
};

/** HMAC digest version; rotation deploys bump this and follow the runbook. */
const DIGEST_VERSION = 1;

/**
 * HMAC(subject) for a Redis key: version-tagged so a rotated key keeps old
 * digests readable for one grace window. Never includes the raw identifier.
 */
export function hmacSubject(
  secret: string,
  namespace: string,
  value: string,
): string {
  const digest = createHmac("sha256", secret)
    .update(`${DIGEST_VERSION}:${namespace}:${value}`)
    .digest("base64url");
  return `v${DIGEST_VERSION}:${digest.slice(0, 24)}`;
}

/**
 * Normalizes a client address into a bounded network prefix for keying.
 * IPv4 (and IPv4-mapped IPv6) keys on the address; IPv6 keys on its /64 so
 * one household's rotation through addresses shares one budget. Returns
 * null when nothing trustworthy is presented - the caller keys that as
 * "unresolved" rather than guessing from spoofable headers.
 */
export function clientIpPrefix(ip: string | null | undefined): string | null {
  if (!ip) return null;
  let address = ip.trim().toLowerCase();
  if (address.includes("%")) {
    address = address.slice(0, address.indexOf("%"));
  }
  // IPv4-mapped IPv6 (::ffff:10.0.0.1) collapses to its IPv4 form.
  const mapped = address.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped?.[1]) {
    return mapped[1];
  }
  if (address.includes(".") && !address.includes(":")) {
    return address;
  }
  // IPv6: aggregate to /64. "::" expands into the zero groups it elides, so
  // head groups fill from the start and tail groups from the end; the first
  // four full groups (zero-padded for stable keys) form the prefix.
  const [head, tail] = address.split("::");
  const headParts = head ? head.split(":").filter(Boolean) : [];
  const tailParts = tail ? tail.split(":").filter(Boolean) : [];
  if (headParts.length + tailParts.length > 8) return null;
  const zeros = Math.max(0, 8 - headParts.length - tailParts.length);
  const full = [...headParts, ...Array<string>(zeros).fill("0"), ...tailParts];
  if (full.length !== 8) return null;
  if (full.some((h) => !/^[0-9a-f]{1,4}$/.test(h))) return null;
  const group = full.slice(0, 4)
    .map((h) => h.padStart(4, "0"))
    .join("-");
  return `v6-${group}`;
}

export interface FlowClassification {
  flow: RateLimitFlow;
  /** Multiplier applied to the flow's per-event cost. */
  weight: number;
}

/**
 * Classifies a /v1 route into its flow and weight. Ordered rules - the
 * catalogue path shape is the contract, not the operationId, so future
 * routes inherit a sane default automatically.
 */
export function flowFor(
  method: "get" | "post",
  path: string,
): FlowClassification {
  if (path === "/webhooks/apple" || path === "/webhooks/google") {
    return { flow: "storeWebhook", weight: 1 };
  }
  if (path === "/v1/billing/school-settings/self-purchase") {
    return { flow: "adminApi", weight: 2 };
  }
  if (
    path === "/v1/billing/purchases" || path === "/v1/billing/restore" ||
    (method === "post" && path === "/v1/billing/purchase-approvals")
  ) {
    return { flow: "billingPurchase", weight: 1 };
  }
  if (/^\/v1\/billing\/purchase-approvals\/[^/]+\/decision$/.test(path)) {
    return { flow: "billingPurchase", weight: 1 };
  }
  // Internal surfaces first: they are all privileged and low-volume.
  if (path.startsWith("/internal/")) {
    return { flow: "adminApi", weight: 2 };
  }
  // Enumeration-prone family linking.
  if (path === "/v1/students/locate" || path.startsWith("/v1/guardian-links")) {
    return { flow: "linking", weight: 2 };
  }
  // The RPC-equivalent write path (matches the public RPC budget).
  if (path === "/v1/notifications/mark-read") {
    return { flow: "rpc", weight: 1 };
  }
  // FILE-050/051 file surface: upload and download intents are costed and
  // fail-closed (the declared uploadIntent flow's owning route is here);
  // status reads are ordinary reads.
  if (
    path === "/v1/uploads" ||
    path.startsWith("/v1/uploads/") ||
    path.startsWith("/v1/files/")
  ) {
    return method === "post"
      ? { flow: "uploadIntent", weight: 2 }
      : { flow: "authenticatedApi", weight: 1 };
  }
  // School-admin command surface: provisioning, lifecycle, staffing,
  // enrollment, invitations, roster creation.
  if (
    path.startsWith("/v1/schools") ||
    path.startsWith("/v1/memberships/")
  ) {
    return method === "get"
      ? {
        flow: "authenticatedApi",
        weight: isCollectionRead(path) ? 2 : 1,
      }
      : { flow: "adminApi", weight: 2 };
  }
  // Moderation and content controls are admin-class wherever they live.
  if (path.startsWith("/v1/control-panel/")) {
    return { flow: "adminApi", weight: 2 };
  }
  // Sensitive session/account lifecycle mutations.
  if (
    (path.startsWith("/v1/auth/") || path.startsWith("/v1/account/")) &&
    method === "post"
  ) {
    return { flow: "auth", weight: 2 };
  }
  if (method === "post") {
    return { flow: "authenticatedApi", weight: 2 };
  }
  // Collections (cursor pages) cost double a single-resource read.
  return isCollectionRead(path) ? { flow: "authenticatedApi", weight: 2 } : {
    flow: "authenticatedApi",
    weight: 1,
  };
}

/**
 * Single-resource reads whose last path segment is a literal (so the
 * trailing-segment heuristic alone would misclassify them as collections).
 * Everything else with a literal last segment is a cursor-paged collection.
 */
export const SINGLE_READ_PATHS: ReadonlySet<string> = new Set([
  "/v1/me",
  "/v1/auth/context",
  "/v1/account/deletion-impact",
  "/v1/account/export-status",
  "/v1/account/export-download",
  "/v1/notifications/unread-count",
  "/v1/notifications/preferences",
  "/internal/moderation/overview",
  "/v1/billing/catalogue",
]);

/** Matches both the canonical {param} segment and a real uuid value. */
const PARAMETER_SEGMENT =
  /^(\{[^}]+\}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i;

function isCollectionRead(path: string): boolean {
  // A trailing parameter segment (canonical or a live uuid value) marks a
  // single-resource read; everything else is a cursor-paged collection.
  const last = path.slice(path.lastIndexOf("/") + 1);
  if (PARAMETER_SEGMENT.test(last)) return false;
  return !SINGLE_READ_PATHS.has(path);
}
