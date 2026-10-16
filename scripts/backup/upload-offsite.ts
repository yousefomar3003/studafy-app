/**
 * Uploads the encrypted backup to the off-site bucket and reads it back
 * (docs/deployment/backups.md). Only ciphertext is uploaded: the workflow
 * runs this after age encryption has deleted the plaintext.
 *
 * Env:
 *   BACKUP_OFFSITE_ENDPOINT, BACKUP_OFFSITE_BUCKET,
 *   BACKUP_OFFSITE_ACCESS_KEY_ID, BACKUP_OFFSITE_SECRET_ACCESS_KEY,
 *   BACKUP_OFFSITE_REGION   required (secrets of the `backups` environment)
 *   BACKUP_OFFSITE_PREFIX   key prefix, default studafy/ (the bucket's
 *                           30-day lifecycle rule is scoped to it)
 *   ENCRYPTED_DIR           directory holding <name>.tar.age and
 *                           <name>.tar.age.sha256
 *
 * Every uploaded object is read back and its sha256 compared with the local
 * file, so a truncated or corrupted upload fails the run. Nothing printed
 * names the endpoint or the bucket: the logs of a public repository are
 * public.
 */
import { readdir } from "node:fs/promises";
import { join } from "node:path";
import { objectKey, OffsiteConfigError, readOffsiteSettings } from "./offsite";

const dir = process.env.ENCRYPTED_DIR;
if (!dir) throw new Error("ENCRYPTED_DIR is required.");

const settings = readOffsiteSettings(process.env);
if (!settings.configured) {
  throw new OffsiteConfigError("The off-site backup is not configured.");
}
const { config } = settings;

const names = (await readdir(dir)).filter((name) =>
  name.endsWith(".tar.age") || name.endsWith(".tar.age.sha256")
).sort();
if (!names.some((name) => name.endsWith(".tar.age"))) {
  throw new Error("No encrypted backup (*.tar.age) to upload.");
}

const client = new Bun.S3Client({
  endpoint: config.endpoint,
  bucket: config.bucket,
  region: config.region,
  accessKeyId: config.accessKeyId,
  secretAccessKey: config.secretAccessKey,
});

async function sha256(stream: ReadableStream<Uint8Array>): Promise<string> {
  const hasher = new Bun.CryptoHasher("sha256");
  for await (const chunk of stream) hasher.update(chunk);
  return hasher.digest("hex");
}

const uploaded: { file: string; bytes: number }[] = [];
for (const name of names) {
  const local = Bun.file(join(dir, name));
  const key = objectKey(config.prefix, name);
  const remote = client.file(key);
  // Multipart for anything larger than one part; retried by Bun per part.
  const writer = remote.writer({
    type: "application/octet-stream",
    partSize: 16 * 1024 * 1024,
    queueSize: 4,
    retry: 3,
  });
  for await (const chunk of local.stream()) {
    await writer.write(chunk);
  }
  await writer.end();

  const stat = await remote.stat();
  if (stat.size !== local.size) {
    throw new Error(
      `Off-site copy of ${name} has ${stat.size} bytes, expected ${local.size}.`,
    );
  }
  const [localSum, remoteSum] = await Promise.all([
    sha256(local.stream()),
    sha256(remote.stream()),
  ]);
  if (localSum !== remoteSum) {
    throw new Error(`Off-site copy of ${name} does not match the local file.`);
  }
  uploaded.push({ file: name, bytes: local.size });
}

// File names and sizes only.
console.log(JSON.stringify({
  event: "backup_offsite_uploaded",
  files: uploaded,
  verified: "sha256 read-back",
}));
