#!/usr/bin/env bash
# Restores a backup made by backup-database.sh into a new database and
# checks it (docs/deployment/backups.md). Used by the scheduled restore test
# and by a real recovery.
#
# Env:
#   RESTORE_ADMIN_URL  required. A superuser connection to the target
#                      cluster's `postgres` database. For the restore test
#                      this is a throwaway Supabase Postgres container
#                      (supabase_admin). For a real recovery, see the runbook.
#   RESTORE_DB         database to create (default studafy_restore_check).
#                      It is dropped first if it exists: never point this at
#                      a database you want to keep.
#   BACKUP_DIR         the decrypted backup directory (default ./backup-out)
#   PG_RESTORE / PSQL  override the client binaries
#   RESTORE_DB_OWNER   owner of the new database (default postgres, as on
#                      Supabase)
#   KEEP_RESTORE_DB=1  leave the restored database in place afterwards
set -euo pipefail

: "${RESTORE_ADMIN_URL:?RESTORE_ADMIN_URL is required}"
db="${RESTORE_DB:-studafy_restore_check}"
dir="${BACKUP_DIR:-backup-out}"
PG_RESTORE="${PG_RESTORE:-pg_restore}"
PSQL="${PSQL:-psql}"

if [[ ! "$db" =~ ^[a-z_][a-z0-9_]*$ || "$db" == "postgres" ]]; then
  echo "RESTORE_DB must be a plain new database name, not postgres" >&2
  exit 1
fi
for file in studafy.dump roles.sql row-counts.tsv manifest.json; do
  [[ -s "$dir/$file" ]] || { echo "missing $dir/$file" >&2; exit 1; }
done

expected=$(sed -n 's/.*"dumpSha256": "\([0-9a-f]*\)".*/\1/p' "$dir/manifest.json")
if command -v sha256sum >/dev/null; then
  actual=$(sha256sum "$dir/studafy.dump" | cut -d' ' -f1)
else
  actual=$(shasum -a 256 "$dir/studafy.dump" | cut -d' ' -f1)
fi
[[ "$expected" == "$actual" ]] || { echo "dump sha256 does not match the manifest" >&2; exit 1; }

target_url="${RESTORE_ADMIN_URL%/*}/$db"
case "$RESTORE_ADMIN_URL" in
  *\?*) echo "RESTORE_ADMIN_URL must not carry query parameters" >&2; exit 1 ;;
esac

admin() { $PSQL "$RESTORE_ADMIN_URL" -X -q -At -v ON_ERROR_STOP=1 "$@"; }
target() { $PSQL "$target_url" -X -q -At -v ON_ERROR_STOP=1 "$@"; }

started=$(date +%s)
admin -c "drop database if exists $db with (force)"
# Supabase's public schema is owned by whoever owns the database, which on
# Supabase is postgres; migrations run as postgres depend on that.
admin -c "create database $db owner ${RESTORE_DB_OWNER:-postgres}"
admin < "$dir/roles.sql"
# A new database has an empty public schema; the dump's own, with its owner
# and grants, replaces it.
target -c 'drop schema public'
# Extensions live in their own schema on Supabase; the dump's tables use
# them but, being outside the dumped schemas, they are not in the dump.
target -c 'create schema if not exists extensions'
target -c 'create extension if not exists pgcrypto with schema extensions'
target -c 'create extension if not exists "uuid-ossp" with schema extensions'

$PG_RESTORE --exit-on-error --no-password --dbname="$target_url" < "$dir/studafy.dump"

# Every table must hold exactly the rows it held in the backup's snapshot.
mismatches=0
while IFS=$'\t' read -r table count; do
  [[ -z "$table" ]] && continue
  schema="${table%%.*}"
  name="${table#*.}"
  restored=$(target -c "select count(*) from \"$schema\".\"$name\"")
  if [[ "$restored" != "$count" ]]; then
    echo "row count mismatch: $table backup=$count restored=$restored" >&2
    mismatches=$((mismatches + 1))
  fi
done < "$dir/row-counts.tsv"

tables=$(wc -l < "$dir/row-counts.tsv" | tr -d ' ')
rows=$(awk -F'\t' '{s += $2} END {print s + 0}' "$dir/row-counts.tsv")
elapsed=$(( $(date +%s) - started ))

if [[ "${KEEP_RESTORE_DB:-0}" != "1" ]]; then
  admin -c "drop database if exists $db with (force)"
fi

if (( mismatches > 0 )); then
  echo "restore check FAILED: $mismatches of $tables tables differ" >&2
  exit 1
fi
echo "restore check passed: $tables tables, $rows rows, ${elapsed}s"
