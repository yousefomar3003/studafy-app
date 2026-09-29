/**
 * Copies every uploaded file out of Supabase Storage for the backup
 * (docs/deployment/backups.md). Database backups - Supabase's own included -
 * hold only the files' metadata (storage.objects), never their bytes.
 *
 * Writes $BACKUP_OUT/storage/<bucket>/<object name> and
 * $BACKUP_OUT/storage-manifest.tsv (bucket, name, bytes, sha256). Like the
 * database dump, the output is plaintext and the caller encrypts it.
 *
 * Env:
 *   BACKUP_DATABASE_URL        lists the objects (storage.objects)
 *   SUPABASE_URL               the project, for downloads
 *   SUPABASE_SERVICE_ROLE_KEY  downloads private objects. A server secret:
 *                              only in the backup job's secret store.
 */
import { mkdir, rm } from "node:fs/promises";
import { dirname, join, normalize, sep } from "node:path";
import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";

const databaseUrl = process.env.BACKUP_DATABASE_URL;
const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!databaseUrl || !supabaseUrl || !serviceRoleKey) {
  throw new Error(
    "BACKUP_DATABASE_URL, SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.",
  );
}
const out = join(process.env.BACKUP_OUT ?? "backup-out", "storage");
await rm(out, { recursive: true, force: true });
await mkdir(out, { recursive: true, mode: 0o700 });

const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
const storage = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
}).storage;

// An object name is a key, not a trusted path: refuse anything that would
// land outside the export directory.
function localPath(bucket: string, name: string): string {
  const path = normalize(join(out, bucket, name));
  if (!path.startsWith(out + sep) || name.includes("\0")) {
    throw new Error("Refusing an object name outside the export directory.");
  }
  return path;
}

try {
  const objects = await sql<{ bucket: string; name: string }[]>`
    select bucket_id as bucket, name from storage.objects
    where name is not null order by bucket_id, name
  `;
  const manifest: string[] = [];
  let bytes = 0;
  let failed = 0;
  for (const object of objects) {
    const { data, error } = await storage.from(object.bucket).download(
      object.name,
    );
    if (error || !data) {
      // A missing object is reported by count, never by name.
      failed += 1;
      continue;
    }
    const content = new Uint8Array(await data.arrayBuffer());
    const path = localPath(object.bucket, object.name);
    await mkdir(dirname(path), { recursive: true, mode: 0o700 });
    await Bun.write(path, content, { mode: 0o600 });
    const digest = new Bun.CryptoHasher("sha256").update(content).digest("hex");
    manifest.push(
      `${object.bucket}\t${object.name}\t${content.byteLength}\t${digest}\n`,
    );
    bytes += content.byteLength;
  }
  await Bun.write(
    join(out, "..", "storage-manifest.tsv"),
    manifest.join(""),
    { mode: 0o600 },
  );
  console.log(JSON.stringify({
    event: "storage_exported",
    objects: manifest.length,
    missing: failed,
    bytes,
  }));
  if (failed > 0) process.exitCode = 1;
} finally {
  await sql.end({ timeout: 5 });
}
