#!/usr/bin/env bash
# Store screenshots on the iOS simulator (launch plan A4).
#
#   scripts/store/capture-ios.sh <stack workdir> <simulator udid> <en|ar> [api url]
#
# Needs: the throwaway stack running, `scripts/store/local-api.ts` serving the
# API on [api url] (default http://127.0.0.1:8095), and
# `scripts/store/seed-store-school.ts` run once on that stack. Writes
# docs/store/screenshots/ios/<locale>/<name>.png.
#
# The test walks the real app to each screen and prints `STORE_SHOT <name>`;
# this script then takes the picture with `simctl io screenshot` (so the
# status bar, overridden to 9:41 and full bars, is in it) and answers by
# creating <name>.done, which lets the test move on.
#
# Afterwards run scripts/store/compress-screenshots.ts: simulator pictures
# carry an alpha channel, which App Store Connect refuses. The student walk
# starts the online exam, so re-seed (reset the stack) before running again.
set -euo pipefail

workdir="$1"
device="$2"
locale="$3"
api="${4:-http://127.0.0.1:8095}"
only="${STORE_ONLY:-}"

repo="$(cd "$(dirname "$0")/../.." && pwd)"
out="$repo/docs/store/screenshots/ios/$locale"
handshake="$(mktemp -d)"
mkdir -p "$out"

# A loaded machine can fail the database's 2-second health check; retry.
status=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  status="$(bunx supabase status --workdir "$workdir" -o env 2>/dev/null)" && break
  status=""
  sleep 5
done
[ -n "$status" ] || { echo "The stack in $workdir is not running." >&2; exit 1; }
value() { printf '%s\n' "$status" | sed -n "s/^$1=\"\(.*\)\"$/\1/p"; }
supabase_url="$(value API_URL)"
publishable_key="$(value PUBLISHABLE_KEY)"
case "$supabase_url" in
  http://127.0.0.1:54321*) echo "Refusing: that is the working stack." >&2; exit 1 ;;
esac

xcrun simctl status_bar "$device" override --time 9:41 \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

cd "$repo"
flutter drive \
  --driver test_driver/iphone_smoke.dart \
  --target integration_test/store_screenshots_test.dart \
  -d "$device" \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL="$supabase_url" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$publishable_key" \
  --dart-define=STUDAFY_API_URL="$api" \
  --dart-define=STORE_LOCALE="$locale" \
  --dart-define=STORE_PASSWORD="Store-Screens-2026!" \
  --dart-define=STORE_PREFIX="${STORE_PREFIX:-store}" \
  --dart-define=STORE_SHOT_DIR="$handshake" \
  --dart-define=STORE_ONLY="$only" 2>&1 |
  while IFS= read -r line; do
    printf '%s\n' "$line"
    case "$line" in
      *"STORE_SHOT "*)
        name="${line##*STORE_SHOT }"
        xcrun simctl io "$device" screenshot --type=png "$out/$name.png" >/dev/null 2>&1
        echo "  -> $out/$name.png"
        touch "$handshake/$name.done"
        ;;
    esac
  done

xcrun simctl status_bar "$device" clear
rm -rf "$handshake"
