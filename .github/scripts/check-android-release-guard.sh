#!/usr/bin/env bash
# SEC-001 / ADR-0042: proves the narrowed Android release guard in
# android/app/build.gradle.kts by running it. Every case below must be refused
# for the stated reason, before any Dart or native compilation starts.
#
# The last case is the one that shows the guard is narrowed rather than
# removed: a development (test copy) release gets past SEC-001 and stops only
# because no upload key is configured. Nothing here builds a release bundle.
#
# Run from the repository root after `flutter pub get`.
set -euo pipefail

unset STUDAFY_ANDROID_KEY_PROPERTIES STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE

readonly sec001='SEC-001: Android release builds are blocked'
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

expect_refusal() {
  local label="$1" reason="$2"
  shift 2
  local log="${work}/build.log"
  if "$@" >"${log}" 2>&1; then
    echo "FAIL ${label}: the release build was not refused" >&2
    exit 1
  fi
  if ! grep -qF "${reason}" "${log}"; then
    echo "FAIL ${label}: refused, but not with '${reason}'" >&2
    tail -n 40 "${log}" >&2
    exit 1
  fi
  echo "ok   ${label}"
}

release=(flutter build appbundle --release --target-platform android-arm64)

expect_refusal "production is refused by SEC-001" "${sec001}" \
  "${release[@]}" --dart-define=APP_ENV=production
expect_refusal "staging is refused by SEC-001" "${sec001}" \
  "${release[@]}" --dart-define=APP_ENV=staging
expect_refusal "no APP_ENV (read as synthetic) is refused by SEC-001" "${sec001}" \
  "${release[@]}"
expect_refusal "development overridden by production is refused by SEC-001" "${sec001}" \
  "${release[@]}" --dart-define=APP_ENV=development --dart-define=APP_ENV=production

# A keystore inside the repository is refused even when everything else is
# valid. pubspec.yaml stands in for it; it is never read as a keystore.
cat >"${work}/key.properties" <<EOF
storeFile=${PWD}/pubspec.yaml
storePassword=placeholder
keyAlias=placeholder
keyPassword=placeholder
EOF
STUDAFY_ANDROID_KEY_PROPERTIES="${work}/key.properties" \
  expect_refusal "a keystore inside the repository is refused" "is inside the repository" \
  "${release[@]}" --dart-define=APP_ENV=development

expect_refusal "development passes SEC-001 and stops at signing" \
  "Release signing: no upload key" \
  "${release[@]}" --dart-define=APP_ENV=development

echo "Android release guard: all cases refused as expected."
