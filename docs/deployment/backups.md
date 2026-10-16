# Backups and recovery

Design and reasoning:
[ADR-0032](../adr/ADR-0032-subscription-lifecycle-and-backups.md).

## What protects the data

| Layer | Covers | Frequency | Kept |
| --- | --- | --- | --- |
| Supabase daily backups (Pro plan and above) | The whole database, restorable in place from the dashboard | Daily | 7 days (Pro), 14 (Team), 30 (Enterprise) |
| Supabase point-in-time recovery (paid add-on) | Restore to any second | Continuous | 7–28 days, by add-on |
| **Studafy backup workflow** (`.github/workflows/backup.yml`) | Database: app data, accounts, file metadata, migration history. Optionally the uploaded files themselves | Every 24 h | 30 days in the off-site bucket (lifecycle rule); 7 days as a fallback artifact until the bucket is set up |

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
5. Uploads the encrypted file to the **off-site bucket** (Cloudflare R2, EU
   jurisdiction, or any S3-compatible store) and reads it back, comparing
   sha256 (`scripts/backup/upload-offsite.ts`). The bucket's lifecycle rule
   deletes it after 30 days. Optionally it is also copied to AWS S3
   (SSE-KMS, below).
6. Keeps a small **manifest** as a workflow artifact (30 days) and in the
   job summary: name, time, encrypted size, sha256, table count, latest
   migration, restore-check result and where the backup went. No row counts,
   names, hosts or bucket names.
7. On any failure, opens a GitHub issue. Runs are daily, so one failure
   still leaves the previous backup under 48 hours old. A failed off-site
   upload fails the run; it never falls back to the public artifact.

### Why not a workflow artifact

The repository is public. In a public repository **any signed-in GitHub
user can download a workflow artifact** of any run, for as long as it is
kept. The backup is age-encrypted, so a download is ciphertext, but a
public copy of every day's database is still more exposure than a private
bucket: it is only as safe as the private key, forever, and it shows the
backup's size and timing to anyone. So once the off-site bucket is set, the
workflow never uploads the backup as an artifact.

**Until the bucket is configured** (none of the five `BACKUP_OFFSITE_*`
secrets set, and no AWS copy), the workflow keeps the old behaviour as a
fallback: the ciphertext is uploaded as an artifact, kept **7 days**
(`BACKUP_ARTIFACT_RETENTION_DAYS`, 1-7), and every run prints a warning and
a job-summary note. Why 7:

- The restore check does not need the artifact at all: it runs on the
  plaintext before encryption, inside the same job.
- The owner does need time to download: a failure opens an issue, and a
  problem in the data (a bad migration, a mistaken delete) can take days to
  notice. Seven daily restore points cover a full week, weekend included,
  for a one-person team, and match the 7 days of Supabase's own Pro-plan
  backups, so the two layers reach back equally far.
- Anything longer is exposure without a recovery need that the off-site
  bucket does not meet better. Set it lower (down to 1, which still keeps
  the 48-hour requirement because runs are daily) if you prefer.

Setting some but not all of the `BACKUP_OFFSITE_*` secrets fails the run
rather than falling back.

### Access

- Backups are **encrypted before they leave the runner**. Anyone who can
  read the bucket (or, in the fallback, download an artifact) gets
  ciphertext. Only the holder of the age
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
   | Secret | `BACKUP_OFFSITE_ENDPOINT` | the bucket's S3 endpoint, e.g. `https://<account id>.eu.r2.cloudflarestorage.com` (next section) |
   | Secret | `BACKUP_OFFSITE_BUCKET` | the bucket name, e.g. `studafy-backups` |
   | Secret | `BACKUP_OFFSITE_ACCESS_KEY_ID` | the API token's Access Key ID |
   | Secret | `BACKUP_OFFSITE_SECRET_ACCESS_KEY` | the API token's Secret Access Key |
   | Secret | `BACKUP_OFFSITE_REGION` | `auto` for R2; the region (an `eu-*` one) for AWS S3 |
   | Variable | `BACKUP_OFFSITE_PREFIX` | optional, default `studafy/` (the lifecycle rule's prefix) |
   | Variable | `BACKUP_ARTIFACT_RETENTION_DAYS` | fallback only, 1-7, default `7` |
   | Variable | `BACKUP_INCLUDE_STORAGE` | `true` to include uploaded files |
   | Secret | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | only with `BACKUP_INCLUDE_STORAGE` |
   | Variable | `BACKUP_S3_BUCKET`, `BACKUP_AWS_ROLE_ARN`, `BACKUP_AWS_REGION` | optional extra AWS copy (below); the region is required and must be `eu-*` |

   The `BACKUP_RETENTION_DAYS` variable is no longer read; delete it.

4. **Create the off-site bucket** (next section) and add the five
   `BACKUP_OFFSITE_*` secrets.

5. **Run it once**: Actions → *Backup (database and files)* → Run workflow.
   Check the log for `restore check passed` and `backup_offsite_uploaded`,
   and that the job summary says `storedIn | offsite` with no warning. The
   run's only artifact should be `studafy-backup-<time>-manifest`.

### Off-site bucket on Cloudflare R2 (click by click)

R2 has no egress fees and a free tier (10 GB-month), and you already have a
Cloudflare account. The bucket must use the **EU jurisdiction**: the data
then stays in the EU, as the privacy policy says of the main systems. The
jurisdiction cannot be changed after creation, and the workflow refuses an
R2 endpoint without `.eu.`.

**Before the first upload:** the privacy policy's processor table (§7.2)
lists GitHub as backup storage. Add Cloudflare (R2, EU) as backup storage
there, in both languages, before turning this on.

1. **Create the bucket.**
   1. Sign in at <https://dash.cloudflare.com> and open your account.
   2. Left menu: **R2 object storage** → **Overview**. (First time only:
      R2 asks you to add a payment method for the free tier; nothing is
      charged within it.)
   3. **Create bucket**.
   4. **Bucket name:** `studafy-backups`.
   5. **Location:** choose **Specify jurisdiction** → **European Union
      (EU)**.
   6. **Default storage class:** Standard.
   7. **Create bucket**.
   8. Leave **Public access** off (the default): no public URL and no
      custom domain.

2. **Add the 30-day lifecycle rule.**
   1. In the bucket: **Settings** tab → **Object lifecycle rules** →
      **Add rule**.
   2. **Rule name:** `delete-backups-after-30-days`.
   3. **Apply to:** objects with the prefix `studafy/`.
   4. Turn on **Delete uploaded objects** after **30 days**.
   5. Keep the default rule that aborts incomplete multipart uploads after
      7 days.
   6. **Save changes**. The rule list should now show the prefix
      `studafy/` and 30 days. (Cloudflare renames buttons from time to
      time; the rule is what matters: prefix `studafy/`, delete after 30
      days.)

   This is what makes "kept for 30 days, then deleted" (privacy policy
   §10) true; the workflow cannot delete anything itself. Cloudflare
   removes expired objects within about a day of expiry.

3. **Optional but recommended: lock the backups.** **Settings** →
   **Bucket lock rules** → **Add rule**: name `keep-30-days`, prefix
   `studafy/`, retention **30 days** → **Save changes**. Nobody, including
   a leaked API token, can then delete or overwrite a backup before it is
   30 days old; the lifecycle rule deletes it afterwards.

4. **Create the API token** (access to this bucket only).
   1. **R2 object storage** → **Overview** → in **Account Details**, next to
      **API Tokens**, select **Manage**.
   2. **Create Account API token** (it survives changes to your own user).
   3. **Token name:** `studafy-backup-github`.
   4. **Permissions:** **Object Read & Write**. (Read is needed: the
      workflow reads each upload back to check it.) Not Admin.
   5. **Specify bucket(s):** **Apply to specific buckets only** →
      `studafy-backups`.
   6. **TTL:** Forever, or a date you will remember to rotate before.
   7. **Client IP address filtering:** leave empty (GitHub's runners have
      no fixed addresses).
   8. **Create Account API token**.
   9. The next page shows the **Access Key ID**, the **Secret Access Key**
      (shown only once) and the endpoints. Copy the **EU jurisdiction**
      endpoint, `https://<account id>.eu.r2.cloudflarestorage.com`, not
      the default one.

5. **Add the secrets.** GitHub → the repository → **Settings** →
   **Environments** → **backups** → **Environment secrets** → **Add
   environment secret**, once for each:

   | Name | Value |
   | --- | --- |
   | `BACKUP_OFFSITE_ENDPOINT` | the EU endpoint from 4.9 |
   | `BACKUP_OFFSITE_BUCKET` | `studafy-backups` |
   | `BACKUP_OFFSITE_ACCESS_KEY_ID` | Access Key ID |
   | `BACKUP_OFFSITE_SECRET_ACCESS_KEY` | Secret Access Key |
   | `BACKUP_OFFSITE_REGION` | `auto` |

   Secrets, not variables, so none of them shows in the public logs. Close
   the token page once all five are saved.

6. **Run the workflow once** (Setup step 5) and check the bucket:
   **R2** → `studafy-backups` → **Objects** → `studafy/` should hold
   `studafy-backup-<time>.tar.age` and its `.sha256`.

7. **Delete the old artifacts** from before the switch: Actions → each
   *Backup* run → Artifacts → delete, or let their retention run out.

Rotate the token yearly or when anyone else had access to it: create a new
one, update the two key secrets, run the workflow, then delete the old
token.

**Another S3-compatible store** (AWS S3, or a provider in the EU) works the
same way: its endpoint, bucket, an access key limited to that bucket, and
its region. For AWS the region must be `eu-*`. Set the 30-day expiry with
the provider's own lifecycle setting.

### Optional: an extra AWS S3 copy

For a second off-site copy on AWS. Create the bucket **in an EU region**
(`eu-central-1`, Frankfurt, next to the database) with versioning, default
SSE-KMS, *Block all public access*, and a lifecycle rule that expires
objects after 30 days (the privacy policy promises 30). Add an IAM role that
trusts GitHub's OIDC provider for this repository and the `backups`
environment only, with `s3:PutObject` on `arn:aws:s3:::<bucket>/studafy/*`
and nothing else. The workflow never holds AWS keys.

`BACKUP_AWS_REGION` is required: there is no default (it used to default to
`il-central-1`, Israel, a transfer the privacy policy does not list), and a
non-`eu-*` region fails the run. With this copy set, the workflow also stops
uploading the backup as an artifact.

## Recovery

You need: the encrypted backup, the age private key, and PostgreSQL 17
client tools.

Get the backup from **R2** → `studafy-backups` → **Objects** → `studafy/`
→ the newest `studafy-backup-<time>.tar.age` → **Download** (or any S3
client with the endpoint and a read token). Check it against the
`.sha256` beside it, or against the `sha256` in that run's manifest
(Actions → the run → summary). Before the bucket existed: Actions → the
run → Artifacts.

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
- **Quarterly** (ADR-0007): decrypt a real backup from the bucket with the offline key,
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
