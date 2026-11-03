#!/usr/bin/env bash
# DL-078 document converter. Starts as root only to stop the converter user
# opening new outbound connections (a document must not call out: no web
# fonts, no linked images, no DNS), then runs the server, and every
# LibreOffice it starts, as that unprivileged user.
#
# Replies to the worker's requests are established connections and still
# flow; loopback stays open. Where the machine's kernel has no netfilter
# owner match the rules cannot be set: that is logged, and the other layers
# (no public address, macros off, links never updated, timeouts) still hold.
set -euo pipefail

block_egress() {
  local tool=$1 uid
  uid=$(id -u converter)
  "$tool" -A OUTPUT -o lo -j ACCEPT &&
    "$tool" -A OUTPUT -m owner --uid-owner "$uid" \
      -m conntrack --ctstate NEW -j REJECT
}

if [ "${CONVERTER_EGRESS_BLOCK:-true}" = "true" ]; then
  if block_egress iptables 2>/dev/null && block_egress ip6tables 2>/dev/null; then
    echo '{"event":"egress_blocked"}'
  else
    echo '{"event":"egress_block_unavailable"}'
  fi
fi

exec runuser -u converter -- python3 /app/server.py
