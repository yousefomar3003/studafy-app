#!/usr/bin/env bash
# Runs the backend-driven device tests on one simulator or emulator:
# integration_test/exam_workflow_device_test.dart and
# integration_test/coursework_files_device_test.dart, against a local API and
# worker on a local Supabase stack (.github/workflows/device-tests.yml,
# docs/testing/device-tests.md).
#
#   tools/ci/run-backend-device-tests.sh <device id>
#
# Needs a running local Supabase stack (reset, nothing else in it) and Redis.
# Starts the API and worker itself with every setting given here - the
# repository's .env is never read - with no AI provider key, seeds the
# synthetic school (scripts/seed-device-tests.ts), runs both tests, and
# stops the API and worker again.
#
#   SUPABASE_WORKDIR  the stack's --workdir, if not this checkout's supabase/
#   E2E_API_PORT      the API's port (default 8090)
#   REDIS_URL         default redis://127.0.0.1:6379
#   E2E_PASSWORD      the synthetic accounts' password (default: random)
#
# Logs and screenshots land in device-logs/backend/.
set -uo pipefail
device="${1:?device id}"
out="device-logs/backend"
mkdir -p "$out"
rm -rf /tmp/studafy-smoke-screenshots

workdir=()
if [ -n "${SUPABASE_WORKDIR:-}" ]; then
  workdir=(--workdir "$SUPABASE_WORKDIR")
fi
# `status -o env` also prints a "Stopped services" line; only KEY="value"
# lines are read. Nothing here is echoed.
eval "$(bunx supabase status ${workdir[@]+"${workdir[@]}"} -o env 2>/dev/null |
  grep -E '^(API_URL|DB_URL|ANON_KEY|SERVICE_ROLE_KEY)="' |
  sed 's/^/STACK_/')"
for name in STACK_API_URL STACK_DB_URL STACK_ANON_KEY STACK_SERVICE_ROLE_KEY; do
  if [ -z "${!name:-}" ]; then
    echo "::error::The local Supabase stack did not report ${name#STACK_}. Is it running?"
    exit 1
  fi
done
case "$STACK_API_URL $STACK_DB_URL" in
  *supabase.co* | *supabase.com*)
    echo "::error::Refusing a hosted Supabase project."
    exit 1
    ;;
esac

port="${E2E_API_PORT:-8090}"
api_url="http://127.0.0.1:$port"
password="${E2E_PASSWORD:-$(openssl rand -hex 16)}"
redis_url="${REDIS_URL:-redis://127.0.0.1:6379}"
defines="build/device-tests/defines.json"

# The API and worker get exactly this environment, nothing inherited: Bun
# would otherwise load the developer's .env, which points elsewhere.
backend_env=(
  PATH="$PATH"
  HOME="$HOME"
  TMPDIR="${TMPDIR:-/tmp}"
  ENVIRONMENT=development
  LOG_LEVEL=info
  API_PORT="$port"
  # The most the API allows. A shared runner (or a laptop building the app)
  # can be slow enough that Storage's first signed upload alone takes
  # seconds; the default 10 s then fails an upload that is not broken.
  API_REQUEST_TIMEOUT_MS=30000
  DATABASE_URL="$STACK_DB_URL"
  REDIS_URL="$redis_url"
  SUPABASE_URL="$STACK_API_URL"
  SUPABASE_SERVICE_ROLE_KEY="$STACK_SERVICE_ROLE_KEY"
  API_CURSOR_SIGNING_KEY="$(openssl rand -hex 32)"
  RATE_LIMIT_HMAC_SIGNING_KEY="$(openssl rand -hex 32)"
  CLASS_JOIN_CODE_KEY="$(openssl rand -hex 32)"
  API041_CLASSES_ENABLED=true
  API041_CONTENT_ENABLED=true
  API041_ASSIGNMENTS_ENABLED=true
  API041_ASSESSMENTS_ENABLED=true
  API041_GRADES_ENABLED=true
  API041_ATTENDANCE_ENABLED=true
  API041_WELLBEING_ENABLED=true
  FILE050_NEW_INTENTS_ENABLED=true
  FILE051_PUBLISH_ENABLED=true
  FILE051_DELIVERY_ENABLED=true
  FILE051_DELIVERY_SIGNING_KEY="$(openssl rand -hex 32)"
  FILE051_DELIVERY_PUBLIC_BASE_URL="$api_url"
  FILE051_SCAN_ENABLED=true
)

pids=()
stop_backend() {
  for pid in ${pids[@]+"${pids[@]}"}; do kill "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
}
trap stop_backend EXIT

env -i "${backend_env[@]}" bun --no-env-file apps/api/src/index.ts \
  >"$out/api.log" 2>&1 &
pids+=($!)
env -i "${backend_env[@]}" bun --no-env-file apps/worker/src/index.ts \
  >"$out/worker.log" 2>&1 &
pids+=($!)

ready=0
for _ in $(seq 1 60); do
  if curl -sf "$api_url/readyz" >/dev/null; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "::error::The local API did not become ready on $api_url"
  tail -n 50 "$out/api.log"
  exit 1
fi

echo "::group::Seed the synthetic school"
if ! env -i PATH="$PATH" HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" \
  E2E_API_URL="$api_url" \
  E2E_SUPABASE_URL="$STACK_API_URL" \
  E2E_DATABASE_URL="$STACK_DB_URL" \
  E2E_ANON_KEY="$STACK_ANON_KEY" \
  E2E_SERVICE_ROLE_KEY="$STACK_SERVICE_ROLE_KEY" \
  E2E_PASSWORD="$password" \
  bun --no-env-file scripts/seed-device-tests.ts --defines "$defines"; then
  echo "::error::Seeding the synthetic school failed"
  exit 1
fi
echo "::endgroup::"

# An Android emulator reaches this machine's ports on its own 127.0.0.1.
if command -v adb >/dev/null && adb -s "$device" get-state >/dev/null 2>&1; then
  supabase_port="${STACK_API_URL##*:}"
  adb -s "$device" reverse "tcp:$port" "tcp:$port"
  adb -s "$device" reverse "tcp:$supabase_port" "tcp:$supabase_port"
fi

failed=0
for test in exam_workflow_device_test coursework_files_device_test; do
  echo "::group::$test"
  if ! flutter drive \
    --driver test_driver/iphone_smoke.dart \
    --target "integration_test/$test.dart" \
    -d "$device" \
    --dart-define-from-file="$defines" 2>&1 | tee "$out/$test.log"; then
    echo "::error::$test failed on $device"
    failed=1
  fi
  echo "::endgroup::"
  if command -v adb >/dev/null && [ -x android/gradlew ]; then
    (cd android && ./gradlew --stop >/dev/null 2>&1) || true
    pkill -f KotlinCompileDaemon 2>/dev/null || true
  fi
done

cp -R /tmp/studafy-smoke-screenshots "$out/screenshots" 2>/dev/null || true
if [ "$failed" -ne 0 ]; then
  if command -v adb >/dev/null && adb -s "$device" get-state >/dev/null 2>&1; then
    adb -s "$device" exec-out screencap -p >"$out/screen.png" || true
    adb -s "$device" logcat -d >"$out/logcat.txt" || true
  elif command -v xcrun >/dev/null; then
    xcrun simctl io "$device" screenshot "$out/screen.png" || true
  fi
fi
exit "$failed"
