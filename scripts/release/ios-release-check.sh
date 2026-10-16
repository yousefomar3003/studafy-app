#!/bin/sh
# Xcode build phase "Release Defines Check" (REL-002 cutover, ADR-0044). It
# replaced the SEC-001 phase that failed every iOS Release build.
#
# A Release build or archive goes ahead only when the dart-defines it
# compiles in (Xcode's DART_DEFINES, written by the Flutter tool into
# ios/Flutter/Generated.xcconfig) pass tools/check_release_defines.dart:
# APP_ENV=production with the production contract, or APP_ENV=development
# (the test copy). Staging, synthetic, a missing APP_ENV and a mix are
# refused, and so is anything that stops the check from running. Debug and
# Profile builds are not checked.
#
# Proved without Xcode or signing by .github/scripts/check-ios-release-guard.sh.
set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

: "${SRCROOT:?SRCROOT is not set; run this as an Xcode build phase}"
: "${FLUTTER_ROOT:?FLUTTER_ROOT is not set; build with flutter or run flutter build ios --config-only first}"

cd "${SRCROOT}/.."
if ! "${FLUTTER_ROOT}/bin/dart" tools/check_release_defines.dart \
  --platform ios --encoded "${DART_DEFINES:-}"; then
  echo "error: REL-002: this iOS release build was refused (see above)."
  exit 1
fi
