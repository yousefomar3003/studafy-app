#!/usr/bin/env bash
# The image's /init starts freshclam and clamd. The HTTP server runs in the
# foreground as the unprivileged clamav user, so the container lives and dies
# with it.
set -euo pipefail

/init &

exec runuser -u clamav -- python3 /app/server.py
