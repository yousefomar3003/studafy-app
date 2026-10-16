#!/usr/bin/env bash
# REL-002 (ADR-0044, after ADR-0042): proves the Android release check in
# android/app/build.gradle.kts by running it. Every case below must be refused
# for the stated reason, before any Dart or native compilation starts.
#
# Two cases show the check lets the right builds through: a production build
# whose defines match the production contract, and a development (test copy)
# build, each get past the defines check and stop only because no upload key
# is configured. Nothing here builds or signs a release bundle.
#
# Run from the repository root after `flutter pub get`.
set -euo pipefail

unset STUDAFY_ANDROID_KEY_PROPERTIES STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE

readonly app_env='REL-002: Android release builds must be APP_ENV=production'
readonly contract='REL-002: production defines check failed'
readonly no_key='Release signing: no upload key'
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

# A production defines file that matches the contract. The publishable key is
# a made-up value of the right shape; nothing here reaches Supabase.
sed \
  -e 's/REPLACE_WITH_sb_publishable_KEY_FROM_SUPABASE_DASHBOARD/sb_publishable_ci0000000000placeholder/' \
  -e 's/REPLACE_WITH_THE_APP_SENTRY_DSN_OR_EMPTY//' \
  config/dart-defines.production.example.json >"${work}/production.json"
production=(--dart-define-from-file="${work}/production.json" --build-number=2)
sed -e 's#https://api.studafy.com#https://studafy-api-test.fly.dev#' \
  "${work}/production.json" >"${work}/test-api.json"

expect_refusal "staging is refused" "${app_env}" \
  "${release[@]}" --dart-define=APP_ENV=staging
expect_refusal "no APP_ENV (read as synthetic) is refused" "${app_env}" \
  "${release[@]}"
expect_refusal "development overridden by production is refused" "${app_env}" \
  "${release[@]}" --dart-define=APP_ENV=development --dart-define=APP_ENV=production

expect_refusal "production with no other defines fails the contract" "${contract}" \
  "${release[@]}" --dart-define=APP_ENV=production --build-number=2
expect_refusal "the unfilled production example fails the contract" \
  "SUPABASE_PUBLISHABLE_KEY must be" \
  "${release[@]}" --dart-define-from-file=config/dart-defines.production.example.json \
  --build-number=2
expect_refusal "production pointed at the test API fails the contract" \
  "STUDAFY_API_URL must be https://api.studafy.com" \
  "${release[@]}" --dart-define-from-file="${work}/test-api.json" --build-number=2
expect_refusal "an unknown define in production fails the contract" \
  "DEMO_MODE is not allowed in a production build" \
  "${release[@]}" "${production[@]}" --dart-define=DEMO_MODE=true
expect_refusal "production without a build number fails the contract" \
  "the build number must be given" \
  "${release[@]}" --dart-define-from-file="${work}/production.json"
STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE=true \
  expect_refusal "production refuses the debug-key opt-in" \
  "STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE is for the development test copy only" \
  "${release[@]}" "${production[@]}"

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

expect_refusal "production matching the contract stops only at signing" "${no_key}" \
  "${release[@]}" "${production[@]}"
expect_refusal "development passes and stops at signing" "${no_key}" \
  "${release[@]}" --dart-define=APP_ENV=development

echo "Android release guard: all cases refused as expected."
