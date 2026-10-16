#!/usr/bin/env bash
# Google Play phone screenshots on an Android emulator (launch plan A4).
#
#   scripts/store/capture-android.sh <stack workdir> <adb serial> <en|ar> [api port]
#
# The Android twin of capture-ios.sh, with the same needs: the throwaway
# stack running, `scripts/store/local-api.ts` serving the API on [api port]
# (default 8095), and `scripts/store/seed-store-school.ts` run once on that
# stack. Writes docs/store/screenshots/android/<locale>/<name>.png.
#
# Use a phone emulator whose screen is at most twice as tall as it is wide
# (Play refuses anything longer), for example an AVD set to 1080 x 2160.
# The 1080 x 2400 Pixel profiles are too tall.
#
# `adb reverse` lets the app reach the stack and the API on 127.0.0.1, as on
# the iOS simulator; the debug build allows plain HTTP to that address only.
# The status bar is put in demo mode (9:41, full battery and signal, no
# notifications). The test prints `STORE_SHOT <name>`; this script takes the
# picture with `adb exec-out screencap` and answers by creating
# <name>.done in the app's cache directory (through `run-as`), which lets the
# test move on.
#
# Afterwards run scripts/store/compress-screenshots.ts on
# docs/store/screenshots/android. The student walk starts the online exam,
# so re-seed (reset the stack) before running again.
set -euo pipefail

workdir="$1"
serial="$2"
locale="$3"
api_port="${4:-8095}"
only="${STORE_ONLY:-}"

repo="$(cd "$(dirname "$0")/../.." && pwd)"
out="$repo/docs/store/screenshots/android/$locale"
package="com.studafy.light"
handshake="/data/user/0/$package/cache/store-shots"
mkdir -p "$out"
adb_bin="${ADB:-$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")}"
# stdin from /dev/null: inside the loop below adb would otherwise read the
# test's output.
adb() { "$adb_bin" -s "$serial" "$@" </dev/null; }

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
supabase_port="${supabase_url##*:}"
supabase_port="${supabase_port%%/*}"

adb reverse "tcp:$supabase_port" "tcp:$supabase_port" >/dev/null
adb reverse "tcp:$api_port" "tcp:$api_port" >/dev/null

demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
# Screen on and unlocked. On a loaded machine System UI can still be
# starting after boot ("System UI isn't responding", no demo clock): look at
# the first picture, and give a fresh emulator a minute before running.
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard
adb shell settings put global sysui_demo_allowed 1
demo enter
demo clock -e hhmm 0941
demo battery -e level 100 -e plugged false -e powersave false
demo network -e wifi show -e level 4 -e fully true
# No mobile icon: the emulator would label it "3G".
demo network -e mobile hide
demo network -e airplane hide
demo notifications -e visible false
demo status -e volume hide -e bluetooth hide -e location hide -e alarm hide \
  -e zen hide -e mute hide -e speakerphone hide -e tty hide -e eri hide \
  -e sync hide -e cast hide -e hotspot hide

cd "$repo"
flutter drive \
  --driver test_driver/iphone_smoke.dart \
  --target integration_test/store_screenshots_test.dart \
  -d "$serial" \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL="$supabase_url" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$publishable_key" \
  --dart-define=STUDAFY_API_URL="http://127.0.0.1:$api_port" \
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
        name="${name%%[[:space:]]*}"
        adb exec-out screencap -p > "$out/$name.png"
        echo "  -> $out/$name.png"
        adb shell run-as "$package" sh -c \
          "'mkdir -p $handshake && touch $handshake/$name.done'" || true
        ;;
    esac
  done

demo exit
adb reverse --remove "tcp:$supabase_port" >/dev/null || true
adb reverse --remove "tcp:$api_port" >/dev/null || true
