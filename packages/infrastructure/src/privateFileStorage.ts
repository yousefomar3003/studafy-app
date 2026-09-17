import { createClient, type SupabaseClient } from "@supabase/supabase-js";

export const FILE_BUCKET = "private-school-files";
export const SIGNED_UPLOAD_TTL_SECONDS = 2 * 60 * 60;
const MAX_FILE_BYTES = 25 * 1024 * 1024;

export interface UploadCapability {
  bucket: typeof FILE_BUCKET;
  objectKey: string;
  nonceHash: string;
  uploadUrl: string;
  expiresAt: string;
}

export interface ObservedObject {
  exists: boolean;
  sizeBytes?: number;
  sha256?: string;
  detectedMediaType?: string | null;
}

export interface PrivateFileStorage {
  createUploadCapability(
    uploadId: string,
    declaredMediaType: string,
  ): Promise<UploadCapability>;
  inspect(
    bucket: string,
    objectKey: string,
    maximumBytes: number,
  ): Promise<ObservedObject>;
  delete(bucket: string, objectKey: string): Promise<void>;
}

export class SupabasePrivateFileStorage implements PrivateFileStorage {
  readonly #client: SupabaseClient;

  constructor(supabaseUrl: string, serviceRoleKey: string) {
    this.#client = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { "X-Client-Info": "studafy-file050" } },
    });
  }

  async createUploadCapability(
    uploadId: string,
    _declaredMediaType: string,
  ): Promise<UploadCapability> {
    const random = crypto.getRandomValues(new Uint8Array(24));
    const segment = Buffer.from(random).toString("base64url");
    const objectKey = `quarantine/v1/${uploadId}/${segment}`;
    const { data, error } = await this.#client.storage.from(FILE_BUCKET)
      .createSignedUploadUrl(objectKey, { upsert: false });
    if (error || !data?.signedUrl) throw new StorageUnavailableError();
    return {
      bucket: FILE_BUCKET,
      objectKey,
      nonceHash: await sha256Hex(new TextEncoder().encode(objectKey)),
      uploadUrl: data.signedUrl,
      expiresAt: new Date(Date.now() + SIGNED_UPLOAD_TTL_SECONDS * 1000)
        .toISOString(),
    };
  }

  async inspect(
    bucket: string,
    objectKey: string,
    maximumBytes: number,
  ): Promise<ObservedObject> {
    assertInternalLocation(bucket, objectKey);
    const store = this.#client.storage.from(bucket);
    const { data: info, error: infoError } = await store.info(objectKey);
    if (infoError) {
      if (/not.?found/i.test(infoError.message)) return { exists: false };
      throw new StorageUnavailableError();
    }
    const size = Number((info as { size?: number }).size);
    if (!Number.isSafeInteger(size) || size < 0) {
      throw new StorageUnavailableError();
    }
    if (size > maximumBytes || size > MAX_FILE_BYTES) {
      return { exists: true, sizeBytes: size };
    }
    const { data, error } = await store.download(objectKey);
    if (error || !data) throw new StorageUnavailableError();
    const bytes = new Uint8Array(await data.arrayBuffer());
    if (bytes.byteLength !== size || bytes.byteLength > maximumBytes) {
      return { exists: true, sizeBytes: bytes.byteLength };
    }
    return {
      exists: true,
      sizeBytes: bytes.byteLength,
      sha256: await sha256Hex(bytes),
      detectedMediaType: detectMediaType(bytes),
    };
  }

  async delete(bucket: string, objectKey: string): Promise<void> {
    assertInternalLocation(bucket, objectKey);
    const { error } = await this.#client.storage.from(bucket).remove([
      objectKey,
    ]);
    if (error) throw new StorageUnavailableError();
  }
}

export class StorageUnavailableError extends Error {
  constructor() {
    super("private storage unavailable");
    this.name = "StorageUnavailableError";
  }
}

// Control characters and separators are stripped on purpose: a display name is
// echoed back to clients and must never carry path or terminal payloads.
// deno-lint-ignore no-control-regex
const UNSAFE_DISPLAY_NAME = /[\\/\u0000-\u001f\u007f]/g;

export function normalizeDisplayName(value: string): string {
  const normalized = value.normalize("NFKC")
    .replaceAll(UNSAFE_DISPLAY_NAME, "_").trim();
  return [...normalized].slice(0, 255).join("") || "upload";
}

export function detectMediaType(bytes: Uint8Array): string | null {
  if (startsWith(bytes, [0x25, 0x50, 0x44, 0x46, 0x2d])) {
    return "application/pdf";
  }
  if (startsWith(bytes, [0xff, 0xd8, 0xff])) return "image/jpeg";
  if (startsWith(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return "image/png";
  }
  if (
    bytes.length >= 12 && ascii(bytes, 0, 4) === "RIFF" &&
    ascii(bytes, 8, 12) === "WEBP"
  ) return "image/webp";
  return null;
}

function ascii(bytes: Uint8Array, start: number, end: number): string {
  return new TextDecoder().decode(bytes.slice(start, end));
}
function startsWith(bytes: Uint8Array, signature: number[]): boolean {
  return bytes.length >= signature.length &&
    signature.every((value, index) => bytes[index] === value);
}
async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
function assertInternalLocation(bucket: string, objectKey: string): void {
  if (
    bucket !== FILE_BUCKET ||
    !/^quarantine\/v1\/[0-9a-f-]{36}\/[A-Za-z0-9_-]{22,64}$/.test(objectKey)
  ) {
    throw new StorageUnavailableError();
  }
}
