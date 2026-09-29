#!/usr/bin/env bash
# Builds a scratch database for capacity tests (docs/operations/capacity.md):
# the current schema of SOURCE_DATABASE_URL with none of its data except the
# reference rows migrations insert, then synthetic schools from
# seed-scale.sql. Pass sizes through to psql, e.g. -v schools=200.
#
# Env:
#   SOURCE_DATABASE_URL  a migrated database to copy the schema from (local)
#   ADMIN_URL            superuser connection to the target cluster's
#                        postgres database (local Supabase: supabase_admin)
#   SCALE_DB             database to (re)create; must contain "scale"
set -euo pipefail
: "${SOURCE_DATABASE_URL:?}"
: "${ADMIN_URL:?}"
db="${SCALE_DB:-studafy_scale}"
case "$db" in *scale*) ;; *) echo "SCALE_DB must contain 'scale'" >&2; exit 1 ;; esac
for url in "$SOURCE_DATABASE_URL" "$ADMIN_URL"; do
  case "$url" in *@127.0.0.1*|*@localhost*) ;; *) echo "local databases only" >&2; exit 1 ;; esac
done
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pg_dump -Fc --schema-only -n public -n private -n auth -n storage -n supabase_migrations \
  "$SOURCE_DATABASE_URL" > "$work/schema.dump"
# Rows migrations insert, which the application reads as configuration.
pg_dump --data-only \
  -t public.store_products -t private.notebook_runtime -t public.consent_policies \
  -t public.file_purpose_policies -t public.file_quota_policies -t private.auth_hash_keys \
  -t supabase_migrations.schema_migrations \
  "$SOURCE_DATABASE_URL" > "$work/reference.sql"

target="${ADMIN_URL%/*}/$db"
psql "$ADMIN_URL" -Xq -v ON_ERROR_STOP=1 -c "drop database if exists $db with (force)" -c "create database $db owner postgres"
psql "$target" -Xq -v ON_ERROR_STOP=1 -c 'drop schema public' -c 'create schema extensions' \
  -c 'create extension pgcrypto with schema extensions' -c 'create extension "uuid-ossp" with schema extensions' \
  -c 'create extension pg_stat_statements with schema extensions'
pg_restore --exit-on-error --no-password -d "$target" "$work/schema.dump"
psql "$target" -Xq -v ON_ERROR_STOP=1 -c 'set session_replication_role = replica' -f "$work/reference.sql" >/dev/null
started=$(date +%s)
psql "$target" -X -v ON_ERROR_STOP=1 "$@" -f "$here/seed-scale.sql"
# Time the statements inside the app's functions too (top-statements.sql).
psql "$ADMIN_URL" -Xq -c "alter database $db set pg_stat_statements.track = 'all'"
echo "seeded $db in $(( $(date +%s) - started ))s"
