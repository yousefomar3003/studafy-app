#!/usr/bin/env bash
set -euo pipefail

readonly blocked_pattern='(^|/)(\.env($|\.)|.*\.(pem|key|p8|p12|pfx|jks|keystore|mobileprovision)$|key\.properties$|google-services\.json$|GoogleService-Info\.plist$|firebase_options\.dart$|.*(service-account|credentials|secrets).*\.json$|supabase/\.temp(/|$)|\.supabase(/|$))'
readonly allowed_pattern='(^|/)\.env\.example$|^config/dart-defines\..*\.example\.json$'

blocked_files="$({ git ls-files | grep -Ei "${blocked_pattern}" || true; } | grep -Eiv "${allowed_pattern}" || true)"

if [[ -n "${blocked_files}" ]]; then
  echo "SEC-001: sensitive or local-only files are tracked:" >&2
  printf '%s\n' "${blocked_files}" >&2
  exit 1
fi

echo "No prohibited sensitive filenames are tracked."
