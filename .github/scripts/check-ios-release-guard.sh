#!/usr/bin/env bash
# REL-002 (ADR-0044): proves the Xcode "Release Defines Check" build phase
# (scripts/release/ios-release-check.sh) without Xcode or signing, by running
# it with the environment Xcode gives it: CONFIGURATION, SRCROOT,
# FLUTTER_ROOT and DART_DEFINES (base64 NAME=value entries joined by commas,
# as the Flutter tool writes them into ios/Flutter/Generated.xcconfig).
#
# Runs on Linux and macOS. Run from the repository root after
# `flutter pub get`.
set -euo pipefail

phase=scripts/release/ios-release-check.sh
flutter_bin="$(command -v flutter)"
flutter_root="${FLUTTER_ROOT:-$(cd "$(dirname "${flutter_bin}")/.." && pwd)}"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# Encodes NAME=value arguments the way the Flutter tool does.
encode() {
  local out="" define
  for define in "$@"; do
    out+="${out:+,}$(printf '%s' "${define}" | base64 | tr -d '\n')"
  done
  printf '%s' "${out}"
}

run_phase() {
  local configuration="$1" defines="$2"
  CONFIGURATION="${configuration}" SRCROOT="${PWD}/ios" \
    FLUTTER_ROOT="${flutter_root}" DART_DEFINES="${defines}" \
    /bin/sh "${phase}"
}

expect() {
  local label="$1" outcome="$2" reason="$3" configuration="$4" defines="$5"
  local log="${work}/phase.log" status=0
  run_phase "${configuration}" "${defines}" >"${log}" 2>&1 || status=$?
  if [[ "${outcome}" == pass && ${status} -ne 0 ]]; then
    echo "FAIL ${label}: refused (exit ${status})" >&2
    cat "${log}" >&2
    exit 1
  fi
  if [[ "${outcome}" == refuse && ${status} -eq 0 ]]; then
    echo "FAIL ${label}: not refused" >&2
    cat "${log}" >&2
    exit 1
  fi
  if [[ -n "${reason}" ]] && ! grep -qF "${reason}" "${log}"; then
    echo "FAIL ${label}: output lacks '${reason}'" >&2
    cat "${log}" >&2
    exit 1
  fi
  echo "ok   ${label}"
}

production=(
  APP_ENV=production
  STUDAFY_API_URL=https://api.studafy.com
  SUPABASE_URL=https://cyrngoqnhqflzovlybbr.supabase.co
  SUPABASE_PUBLISHABLE_KEY=sb_publishable_ci0000000000placeholder
  STUDAFY_PRIVACY_URL=https://legal.studafy.com/privacy
  STUDAFY_TERMS_URL=https://legal.studafy.com/terms
  TURNSTILE_ENABLED=true
  APPLE_SIGN_IN_ENABLED=true
  SENTRY_DSN=
  FLUTTER_BUILD_NAME=1.0.0
  FLUTTER_BUILD_NUMBER=2
  FLUTTER_VERSION=3.47.1
)
good="$(encode "${production[@]}")"

expect "Debug is not checked" pass "" Debug ""
expect "Profile is not checked" pass "" Profile "$(encode APP_ENV=staging)"
expect "Release with no APP_ENV is refused" refuse "APP_ENV given: none" Release ""
expect "Release of staging is refused" refuse "APP_ENV given: staging" \
  Release "$(encode APP_ENV=staging)"
expect "Release of synthetic is refused" refuse "APP_ENV given: synthetic" \
  Release "$(encode APP_ENV=synthetic)"
expect "development overridden by production is refused" refuse \
  "APP_ENV given: development, production" \
  Release "$(encode APP_ENV=development APP_ENV=production)"
expect "production with no other defines fails the contract" refuse \
  "production defines contract" Release "$(encode APP_ENV=production)"
expect "production pointed at the test API fails the contract" refuse \
  "STUDAFY_API_URL must be https://api.studafy.com" \
  Release "$(encode "${production[@]/https:\/\/api.studafy.com/https://studafy-api-test.fly.dev}")"
expect "a define given twice fails the contract" refuse \
  "STUDAFY_API_URL is given 2 times" \
  Release "${good},$(encode STUDAFY_API_URL=https://api.studafy.com)"
expect "production without Sign in with Apple fails on iOS" refuse \
  "APPLE_SIGN_IN_ENABLED must be true for an iOS build" \
  Release "$(encode "${production[@]/APPLE_SIGN_IN_ENABLED=true/APPLE_SIGN_IN_ENABLED=false}")"
expect "production with the baseline build number fails" refuse \
  "the build number must be given" \
  Release "$(encode "${production[@]/FLUTTER_BUILD_NUMBER=2/FLUTTER_BUILD_NUMBER=1}")"
expect "an unknown define in production fails the contract" refuse \
  "DEMO_MODE is not allowed in a production build" \
  Release "${good},$(encode DEMO_MODE=true)"
expect "a service-role value fails the contract" refuse \
  "looks like a server secret" \
  Release "$(encode "${production[@]/SENTRY_DSN=/SENTRY_DSN=service_role}")"
expect "a broken DART_DEFINES fails closed" refuse "could not be read" \
  Release "not-base64!"
expect "production matching the contract passes" pass \
  "production contract passed (ios)" Release "${good}"
expect "development (test copy) passes" pass "development test copy" \
  Release "$(encode APP_ENV=development)"

echo "iOS release check: all cases behaved as expected."
