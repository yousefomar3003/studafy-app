# Backups and recovery

Design and reasoning:
[ADR-0032](../adr/ADR-0032-subscription-lifecycle-and-backups.md).

## What protects the data

| Layer | Covers | Frequency | Kept |
| --- | --- | --- | --- |
| Supabase daily backups (Pro plan and above) | The whole database, restorable in place from the dashboard | Daily | 7 days (Pro), 14 (Team), 30 (Enterprise) |
| Supabase point-in-time recovery (paid add-on) | Restore to any second | Continuous | 7–28 days, by add-on |
| **Studafy backup workflow** (`.github/workflows/backup.yml`) | Database: app data, accounts, file metadata, migration history. Optionally the uploaded files themselves | Every 24 h | 30 days (configurable) |

Supabase's own backups restore only into the same project, and they do not
contain the bytes of files in Storage. The Free plan has no downloadable
backups at all. The workflow covers all three gaps: a copy outside Supabase,
restorable anywhere, including the files. Keep Supabase's backups on as well
(Pro plan). They are the fastest path for an in-place restore.

## The workflow

Each run, daily at 02:17 UTC or on demand:

1. Dumps the `public`, `private`, `auth`, `storage` and
   `supabase_migrations` schemas from one consistent snapshot, with exact
   row counts from that same snapshot (`scripts/backup/backup-database.ts`).
2. If enabled, copies every object from Storage with a sha256 manifest
   (`scripts/backup/export-storage.ts`).
3. **Restore test:** restores the dump into a fresh Supabase Postgres
   container and checks every table's row count against the snapshot
   (`scripts/backup/restore-database.sh`). A backup that does not restore
   exactly fails the run and is not kept.
4. Encrypts everything with [age](https://age-encryption.org) to your
   public key, then deletes the plaintext.
5. Keeps the encrypted file as a workflow artifact (30 days), plus
   optionally an S3 copy (SSE-KMS).
6. On any failure, opens a GitHub issue. Runs are daily, so one failure
   still leaves the previous backup under 48 hours old.

### Access

- Backups are **encrypted before they leave the runner**. Anyone who can
  download an artifact gets ciphertext. Only the holder of the age
  **private** key can read a backup, and that key is never in GitHub, on a
  server or in this repository.
- The database credentials live only in the protected GitHub environment
  `backups`. Add required reviewers or restrict it to `main` (Settings →
  Environments → backups → Deployment protection rules).
- Use a dedicated read-only database role for `BACKUP_DATABASE_URL` (below),
  not `postgres`.

## Setup

1. **Make the key pair** on your own machine (`brew install age`):

   ```sh
   age-keygen -o studafy-backup.key
   ```

   The file holds the private key. Put it in your password manager, with a
   second offline copy, then delete the file. The line
   `Public key: age1...` is the public key.

2. **Create a read-only backup role** (Supabase SQL editor, as `postgres`):

   ```sql
   create role studafy_backup login password '<long random password>' bypassrls;
   grant pg_read_all_data to studafy_backup;
   ```

   `BACKUP_DATABASE_URL` is the **session pooler** connection string (port
   5432) with this user, or the direct connection. The transaction pooler
   (6543) cannot hold the snapshot.

3. **GitHub → Settings → Environments → New environment `backups`**:

   | Kind | Name | Value |
   | --- | --- | --- |
   | Secret | `BACKUP_DATABASE_URL` | step 2 |
   | Variable | `BACKUP_AGE_RECIPIENTS` | the `age1...` public key (one per line for several holders) |
   | Variable | `BACKUP_RETENTION_DAYS` | optional, default `30` (GitHub's maximum is 90) |
   | Variable | `BACKUP_INCLUDE_STORAGE` | `true` to include uploaded files |
   | Secret | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | only with `BACKUP_INCLUDE_STORAGE` |
   | Variable | `BACKUP_S3_BUCKET`, `BACKUP_AWS_ROLE_ARN`, `BACKUP_AWS_REGION` | optional off-site copy (below) |

4. **Run it once**: Actions → *Backup (database and files)* → Run workflow.
   Check the log for `restore check passed`.

### Optional: S3 copy with longer retention

Create a bucket with versioning, default SSE-KMS, *Block all public access*,
and a lifecycle rule (for example, expire after 90 days). Add an IAM role
that trusts GitHub's OIDC provider for this repository and the `backups`
environment only, with `s3:PutObject` on `arn:aws:s3:::<bucket>/studafy/*`
and nothing else. The workflow never holds AWS keys.

## Recovery

You need: the encrypted backup (Actions → the run → Artifacts, or S3), the
age private key, and PostgreSQL 17 client tools.

```sh
age --decrypt --identity studafy-backup.key studafy-backup-<time>.tar.age \
  | tar -x -C ./restore
```

**Into a new or replacement Supabase project:**

1. Create the project (same Postgres major version: 17).
2. Restore with the project's direct connection. The admin URL must reach
   its `postgres` database; the script creates the target database:

   ```sh
   BACKUP_DIR=./restore RESTORE_ADMIN_URL='postgresql://postgres:<pw>@db.<ref>.supabase.co:5432/postgres' \
   RESTORE_DB=studafy_restored KEEP_RESTORE_DB=1 \
   bash scripts/backup/restore-database.sh
   ```

   To replace the `postgres` database itself, restore the dump into a fresh
   project with `pg_restore --clean --if-exists -d <url> ./restore/studafy.dump`
   after running `roles.sql`, and check the counts against
   `row-counts.tsv`.
3. Set passwords for the runtime roles (`roles.sql` recreates them without
   login passwords), point `DATABASE_URL` at the project, and apply any
   migration newer than `latestMigration` in `manifest.json`.
4. Files: upload `storage/<bucket>/…` back into the same bucket and paths.
   Check them against `storage-manifest.tsv`.

**A single table or rows:** restore into a scratch database as above, then
copy the rows across with `psql`. Never restore over live data you have not
compared first.

## Restore drills

- **Every run:** the automatic restore check (step 3).
- **Quarterly** (ADR-0007): decrypt a real artifact with the offline key,
  restore into a scratch project, sign in as a test account, and record how
  long it took and any gaps.

The first drill was run on 2026-09-29 against the local development
database. The backup was taken (122 tables, 742 rows, snapshot-consistent)
and restored into a fresh `supabase/postgres:17.6.1.166` container: every row
count matched, and so did the functions (279), RLS policies (30), triggers
(144), runtime grants (89) and a hash of every private function definition.
An age encrypt → decrypt round trip produced an identical dump, and without
the key the backup could not be decrypted. The hosted project has not been
backed up by the workflow yet: that needs the `backups` environment above.
