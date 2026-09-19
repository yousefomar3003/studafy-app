#!/usr/bin/env bash
# INFRA-081 / REL-002 §21.4: the mobile build number is owned by CI.
#
# Both stores refuse an upload whose build number is not strictly greater
# than every earlier upload, including rejected ones. GITHUB_RUN_NUMBER
# increases on every run of the release workflow and is never reused, and
# that workflow is the only path that produces store artifacts, so the
# result is strictly increasing. The offset keeps it above the hand-edited
# 1.0.0+1 baseline in pubspec.yaml.
set -euo pipefail
: "${GITHUB_RUN_NUMBER:?build-number.sh must run inside GitHub Actions}"
echo $((1000 + GITHUB_RUN_NUMBER))
