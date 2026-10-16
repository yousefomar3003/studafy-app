/**
 * Where the encrypted backup is kept off-site (docs/deployment/backups.md):
 * any S3-compatible bucket, Cloudflare R2 by default. Pure functions, so the
 * workflow's decisions are tested without a bucket (offsite.test.ts).
 *
 * The repository is public, so a GitHub Actions artifact can be downloaded
 * by any signed-in GitHub user. Once this destination is configured the
 * backup goes only here, and the workflow keeps just a small manifest as an
 * artifact.
 */

export interface OffsiteConfig {
  endpoint: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  region: string;
  /** Key prefix inside the bucket; the lifecycle rule is scoped to it. */
  prefix: string;
}

/** The five secrets of the `backups` environment, by their names. */
export const OFFSITE_SECRETS = [
  "BACKUP_OFFSITE_ENDPOINT",
  "BACKUP_OFFSITE_BUCKET",
  "BACKUP_OFFSITE_ACCESS_KEY_ID",
  "BACKUP_OFFSITE_SECRET_ACCESS_KEY",
  "BACKUP_OFFSITE_REGION",
] as const;

export const DEFAULT_PREFIX = "studafy/";

export type OffsiteSettings =
  | { configured: false }
  | { configured: true; config: OffsiteConfig };

export class OffsiteConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "OffsiteConfigError";
  }
}

/**
 * None set: not configured (the workflow falls back to a short-lived
 * artifact). All set: configured. Some set: an error, never a silent fallback
 * to the public artifact.
 */
export function readOffsiteSettings(
  env: Record<string, string | undefined>,
): OffsiteSettings {
  const present = OFFSITE_SECRETS.filter((name) =>
    (env[name] ?? "").trim() !== ""
  );
  if (present.length === 0) return { configured: false };
  const missing = OFFSITE_SECRETS.filter((name) => !present.includes(name));
  if (missing.length > 0) {
    throw new OffsiteConfigError(
      `The off-site backup is half configured; missing: ${missing.join(", ")}`,
    );
  }
  const prefix = (env.BACKUP_OFFSITE_PREFIX ?? "").trim() || DEFAULT_PREFIX;
  if (!/^[a-z0-9][a-z0-9._/-]*\/$/.test(prefix) || prefix.includes("..")) {
    throw new OffsiteConfigError(
      "BACKUP_OFFSITE_PREFIX must be a plain path ending in / (e.g. studafy/)",
    );
  }
  const config: OffsiteConfig = {
    endpoint: env.BACKUP_OFFSITE_ENDPOINT!.trim().replace(/\/+$/, ""),
    bucket: env.BACKUP_OFFSITE_BUCKET!.trim(),
    accessKeyId: env.BACKUP_OFFSITE_ACCESS_KEY_ID!.trim(),
    secretAccessKey: env.BACKUP_OFFSITE_SECRET_ACCESS_KEY!.trim(),
    region: env.BACKUP_OFFSITE_REGION!.trim(),
    prefix,
  };
  const problem = locationProblem(config.endpoint, config.region);
  if (problem) throw new OffsiteConfigError(problem);
  return { configured: true, config };
}

const LOOPBACK = new Set(["127.0.0.1", "localhost", "[::1]"]);

/**
 * The privacy policy (§7.2, §8) keeps the main systems in the EU, so the
 * backup must stay there too:
 * - Cloudflare R2: a bucket created with the EU jurisdiction, whose endpoint
 *   is `https://<account>.eu.r2.cloudflarestorage.com`. Its region is `auto`.
 * - AWS S3: an `eu-*` region.
 * - Any other S3-compatible provider: an explicit region, checked by the
 *   owner against the privacy policy (the workflow cannot know its geography).
 * The endpoint must be https, except a loopback test server (local dry run).
 */
export function locationProblem(
  endpoint: string,
  region: string,
): string | null {
  let url: URL;
  try {
    url = new URL(endpoint);
  } catch {
    return "BACKUP_OFFSITE_ENDPOINT is not a URL";
  }
  if (url.username || url.password || url.search || url.hash) {
    return "BACKUP_OFFSITE_ENDPOINT must be a bare https://host URL";
  }
  const loopback = LOOPBACK.has(url.hostname);
  if (url.protocol !== "https:" && !(loopback && url.protocol === "http:")) {
    return "BACKUP_OFFSITE_ENDPOINT must use https";
  }
  if (!/^[a-z0-9-]+$/.test(region)) {
    return "BACKUP_OFFSITE_REGION must be set explicitly (R2: auto; AWS: e.g. eu-central-1)";
  }
  const host = url.hostname.toLowerCase();
  if (host.endsWith(".r2.cloudflarestorage.com")) {
    if (!host.endsWith(".eu.r2.cloudflarestorage.com")) {
      return "The R2 bucket must use the EU jurisdiction (endpoint https://<account>.eu.r2.cloudflarestorage.com)";
    }
    return null;
  }
  if (host.endsWith(".amazonaws.com") && !region.startsWith("eu-")) {
    return `AWS region ${region} is outside the EU; use an eu-* region such as eu-central-1`;
  }
  return null;
}

/** Object key for a local file name. */
export function objectKey(prefix: string, fileName: string): string {
  if (!/^[A-Za-z0-9._-]+$/.test(fileName)) {
    throw new OffsiteConfigError(`unexpected backup file name: ${fileName}`);
  }
  return `${prefix}${fileName}`;
}
