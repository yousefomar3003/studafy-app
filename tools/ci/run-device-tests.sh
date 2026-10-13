#!/usr/bin/env bash
# Runs the device smoke tests on one simulator or emulator (launch plan 7.1,
# .github/workflows/device-tests.yml). Synthetic build only: no backend, no
# sign-in, no purchase.
#
#   tools/ci/run-device-tests.sh <device id>
#
# Everything worth keeping lands in device-logs/: each test's log, the
# screenshots the tests take, and on failure a picture of the screen and,
# on Android, the system log.
set -uo pipefail
device="${1:?device id}"
out="device-logs"
mkdir -p "$out"
rm -rf /tmp/studafy-smoke-screenshots

failed=0
for test in iphone_smoke_test family_challenge_smoke_test study_plans_smoke_test; do
  echo "::group::$test"
  if ! flutter drive \
    --driver test_driver/iphone_smoke.dart \
    --target "integration_test/$test.dart" \
    -d "$device" \
    --dart-define=APP_ENV=synthetic 2>&1 | tee "$out/$test.log"; then
    echo "::error::$test failed on $device"
    failed=1
  fi
  echo "::endgroup::"
  # On Android, stop the Kotlin compile daemon and any Gradle daemon between
  # builds, so the emulator keeps its memory (device-tests.yml).
  if command -v adb >/dev/null && [ -x android/gradlew ]; then
    (cd android && ./gradlew --stop >/dev/null 2>&1) || true
    pkill -f KotlinCompileDaemon 2>/dev/null || true
  fi
done

cp -R /tmp/studafy-smoke-screenshots "$out/screenshots" 2>/dev/null || true
if [ "$failed" -ne 0 ]; then
  if command -v adb >/dev/null && adb -s "$device" get-state >/dev/null 2>&1; then
    adb -s "$device" exec-out screencap -p > "$out/screen.png" || true
    adb -s "$device" logcat -d > "$out/logcat.txt" || true
  elif command -v xcrun >/dev/null; then
    xcrun simctl io "$device" screenshot "$out/screen.png" || true
  fi
fi
exit "$failed"
