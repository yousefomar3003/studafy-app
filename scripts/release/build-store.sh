#!/usr/bin/env bash
# Store build (REL-002 cutover, ADR-0044): checks the production defines
# contract, then builds the Play bundle or the App Store archive with it.
#
#   scripts/release/build-store.sh android|ios --build-number N [--defines FILE]
#
# FILE defaults to config/dart-defines.production.json, made from
# config/dart-defines.production.example.json and git-ignored; it must not be
# tracked. N is the store build number (Android versionCode, iOS
# CFBundleVersion): strictly above every earlier upload to that store,
# including rejected ones. In GitHub Actions it defaults to
# .github/scripts/build-number.sh. The version name comes from pubspec.yaml.
#
# Android signs with the upload key named by STUDAFY_ANDROID_KEY_PROPERTIES
# (or android/key.properties), outside the repository; the debug-key opt-in
# is refused. iOS signs with the owner's team in Xcode (flutter build ipa).
#
# Gradle and the Xcode "Release Defines Check" phase repeat the same check on
# what is actually compiled, so a build started some other way is held to it
# too. No production build may be uploaded until https://api.studafy.com is
# live (DL-069).
#
# Run from the repository root.
set -euo pipefail

usage() {
  echo "usage: scripts/release/build-store.sh android|ios --build-number N [--defines FILE]" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
platform="$1"
shift
case "${platform}" in
  android | ios) ;;
  *) usage ;;
esac

defines="config/dart-defines.production.json"
build_number=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-number)
      [[ $# -ge 2 ]] || usage
      build_number="$2"
      shift 2
      ;;
    --defines)
      [[ $# -ge 2 ]] || usage
      defines="$2"
      shift 2
      ;;
    *) usage ;;
  esac
done

if [[ -z "${build_number}" && -n "${GITHUB_RUN_NUMBER:-}" ]]; then
  build_number="$(.github/scripts/build-number.sh)"
fi
if ! [[ "${build_number}" =~ ^[0-9]+$ ]] || ((build_number <= 1)); then
  echo "error: --build-number must be a whole number above 1 and above every earlier upload" >&2
  exit 1
fi

if [[ ! -f "${defines}" ]]; then
  echo "error: ${defines} does not exist. Copy config/dart-defines.production.example.json" >&2
  echo "       to it and fill SUPABASE_PUBLISHABLE_KEY (Supabase dashboard > Project" >&2
  echo "       Settings > API Keys, the sb_publishable_ key) and SENTRY_DSN (the app's" >&2
  echo "       Sentry project DSN, or empty)." >&2
  exit 1
fi
if git ls-files --error-unmatch -- "${defines}" >/dev/null 2>&1; then
  echo "error: ${defines} is tracked by git; production defines stay out of the repository" >&2
  exit 1
fi

dart tools/check_release_defines.dart \
  --platform "${platform}" --file "${defines}" --build-number "${build_number}"

case "${platform}" in
  android)
    if [[ "${STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE:-}" == "true" ]]; then
      echo "error: STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE is for development builds only" >&2
      exit 1
    fi
    if [[ -z "${STUDAFY_ANDROID_KEY_PROPERTIES:-}" && ! -f android/key.properties ]]; then
      echo "error: set STUDAFY_ANDROID_KEY_PROPERTIES to the upload key's key.properties" >&2
      echo "       (outside the repository; ADR-0042 'Building the internal-testing bundle')" >&2
      exit 1
    fi
    flutter build appbundle --release \
      --dart-define-from-file="${defines}" \
      --build-number="${build_number}"
    echo "Built build/app/outputs/bundle/release/app-release.aab (versionCode ${build_number})."
    ;;
  ios)
    flutter build ipa --release \
      --dart-define-from-file="${defines}" \
      --build-number="${build_number}"
    echo "Built build/ios/ipa (CFBundleVersion ${build_number})."
    ;;
esac
