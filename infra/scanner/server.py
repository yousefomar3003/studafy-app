#!/usr/bin/env python3
"""FILE-051 malware scanner: an authenticated HTTP front for clamd.

Speaks the ExternalMalwareScannerClient contract
(packages/infrastructure/src/fileScanner.ts):

    POST /scan   Authorization: Bearer <SCANNER_API_KEY>, body = the file
                 200 {"clean": true}  clamd answered "stream: OK"
                 200 {"clean": false} clamd answered "stream: <sig> FOUND"
                 503                  anything else: never fail open
    GET /healthz 200 only when clamd answers PING and the self-test passed

After the self-test a watchdog PINGs clamd every 30 seconds; if clamd stays
unreachable for WATCHDOG_LIMIT_SECONDS (default 300, which covers a pause
while it reloads its virus definitions) the process exits, so the machine
restarts. Listens dual-stack on [::]:PORT: Fly's private network is IPv6.

Standard library only. File bytes are streamed to clamd and never stored or
logged; logs are one JSON line per event with the verdict, size, duration
and signature name only - never file contents or names.
"""

import hmac
import json
import os
import socket
import struct
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CLAMD_HOST = "127.0.0.1"
CLAMD_PORT = 3310
CHUNK_BYTES = 64 * 1024
CLAMD_TIMEOUT_S = 25
PORT = int(os.environ.get("PORT", "8080"))
MAX_BYTES = int(os.environ.get("MAX_BYTES", str(50 * 1024 * 1024)))
SELFTEST_TIMEOUT_S = int(os.environ.get("SELFTEST_TIMEOUT_S", "600"))
WATCHDOG_INTERVAL_S = 30
WATCHDOG_LIMIT_S = int(os.environ.get("WATCHDOG_LIMIT_SECONDS", "300"))

API_KEY = os.environ.get("SCANNER_API_KEY", "")
if len(API_KEY) < 32:
    print("scanner: SCANNER_API_KEY is missing or shorter than 32 characters",
          file=sys.stderr, flush=True)
    sys.exit(1)
EXPECTED_AUTH = ("Bearer " + API_KEY).encode()

# The EICAR antivirus test string, assembled at runtime so this source file
# is not itself flagged by antivirus software on a developer's machine.
EICAR = "".join([
    "X5O!P%@AP[4\\PZX54(P^)7CC)7}$",
    "EICAR-STANDARD-",
    "ANTIVIRUS-TEST-",
    "FILE!$H+H*",
]).encode()
HARMLESS = b"Studafy scanner self-test: an ordinary sentence.\n"

self_test_passed = threading.Event()


class ClamdError(Exception):
    """clamd was unreachable or gave an answer we cannot trust."""


def log(event, **fields):
    print(json.dumps({"event": event, **fields}), flush=True)


def clamd_connect():
    return socket.create_connection((CLAMD_HOST, CLAMD_PORT), timeout=CLAMD_TIMEOUT_S)


def read_reply(sock):
    reply = b""
    while not reply.endswith(b"\0"):
        part = sock.recv(4096)
        if not part:
            break
        reply += part
    return reply.rstrip(b"\0").decode("utf-8", "replace").strip()


def clamd_ping():
    try:
        with clamd_connect() as sock:
            sock.sendall(b"zPING\0")
            return read_reply(sock) == "PONG"
    except OSError:
        return False


def scan_stream(read_chunk):
    """Streams chunks from read_chunk() to clamd INSTREAM. Returns
    (True, None) when clean, (False, signature) when a signature was found;
    ClamdError for anything else."""
    try:
        with clamd_connect() as sock:
            sock.sendall(b"zINSTREAM\0")
            while True:
                chunk = read_chunk()
                if not chunk:
                    break
                sock.sendall(struct.pack("!L", len(chunk)) + chunk)
            sock.sendall(struct.pack("!L", 0))
            reply = read_reply(sock)
    except OSError as error:
        raise ClamdError(type(error).__name__) from error
    if reply == "stream: OK":
        return True, None
    if reply.startswith("stream: ") and reply.endswith(" FOUND"):
        return False, reply[len("stream: "):-len(" FOUND")]
    raise ClamdError("unexpected clamd reply")


def scan_bytes(data):
    chunks = [data[i:i + CHUNK_BYTES] for i in range(0, len(data), CHUNK_BYTES)]
    return scan_stream(lambda: chunks.pop(0) if chunks else b"")[0]


def self_test():
    """Waits for clamd, then proves it detects EICAR and passes a harmless
    string. A scanner that cannot do both must not serve: exit."""
    deadline = time.monotonic() + SELFTEST_TIMEOUT_S
    while not clamd_ping():
        if time.monotonic() > deadline:
            log("selftest_failed", reason="clamd_not_ready")
            os._exit(1)
        time.sleep(2)
    try:
        detects = scan_bytes(EICAR) is False
        passes = scan_bytes(HARMLESS) is True
    except ClamdError as error:
        log("selftest_failed", reason=str(error))
        os._exit(1)
    if not (detects and passes):
        log("selftest_failed", detects_eicar=detects, passes_harmless=passes)
        os._exit(1)
    self_test_passed.set()
    log("selftest_ok")
    watchdog()


def watchdog():
    """Exits once clamd has missed enough consecutive PINGs to cover
    WATCHDOG_LIMIT_S (10 at the default 300 s); any answer resets the count.
    Scans fail closed meanwhile; the restart brings clamd back."""
    limit = max(1, WATCHDOG_LIMIT_S // WATCHDOG_INTERVAL_S)
    failures = 0
    while True:
        time.sleep(WATCHDOG_INTERVAL_S)
        if clamd_ping():
            failures = 0
            continue
        failures += 1
        if failures >= limit:
            log("clamd_down_restarting", failed_pings=failures,
                seconds=failures * WATCHDOG_INTERVAL_S)
            os._exit(1)


class Handler(BaseHTTPRequestHandler):
    server_version = "studafy-scanner"
    sys_version = ""
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        pass  # one structured line per request instead, below

    def respond(self, status, body=None):
        payload = json.dumps(body).encode() if body is not None else b""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        if self.close_connection:
            self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path != "/healthz":
            self.respond(404, {"error": "not_found"})
            return
        healthy = self_test_passed.is_set() and clamd_ping()
        self.respond(200 if healthy else 503, {"ok": healthy})

    def do_POST(self):
        if self.path != "/scan":
            self.close_connection = True
            self.respond(404, {"error": "not_found"})
            return
        started = time.monotonic()
        provided = self.headers.get("Authorization", "").encode()
        if not hmac.compare_digest(provided, EXPECTED_AUTH):
            self.close_connection = True
            self.respond(401, {"error": "unauthorized"})
            log("auth_rejected")
            return
        length_header = self.headers.get("Content-Length")
        try:
            length = int(length_header)
        except (TypeError, ValueError):
            length = -1
        if length < 0:
            self.close_connection = True
            self.respond(411, {"error": "length_required"})
            log("scan_error", status=411, reason="length_required")
            return
        if length > MAX_BYTES:
            self.close_connection = True
            self.respond(413, {"error": "too_large"})
            log("too_large", bytes=length)
            return
        if not self_test_passed.is_set():
            self.close_connection = True
            self.respond(503, {"error": "not_ready"})
            log("scan_error", status=503, reason="not_ready")
            return

        remaining = [length]

        def read_chunk():
            if remaining[0] == 0:
                return b""
            chunk = self.rfile.read(min(CHUNK_BYTES, remaining[0]))
            if not chunk:
                raise ClamdError("request body ended early")
            remaining[0] -= len(chunk)
            return chunk

        try:
            clean, signature = scan_stream(read_chunk)
        except ClamdError as error:
            self.close_connection = True
            self.respond(503, {"error": "scan_unavailable"})
            log("scan_error", status=503, reason=str(error), bytes=length)
            return
        except Exception:  # never fail open, whatever went wrong
            self.close_connection = True
            self.respond(503, {"error": "scan_unavailable"})
            log("scan_error", status=503, reason="internal", bytes=length)
            return
        self.respond(200, {"clean": clean})
        fields = {"verdict": "clean" if clean else "malicious", "bytes": length,
                  "ms": round((time.monotonic() - started) * 1000)}
        if signature:
            fields["signature"] = signature
        log("scan", **fields)

    def do_PUT(self):
        self.close_connection = True
        self.respond(405, {"error": "method_not_allowed"})

    do_DELETE = do_PATCH = do_PUT


class DualStackServer(ThreadingHTTPServer):
    """[::]:PORT, accepting IPv4 too: Fly's private network is IPv6."""
    address_family = socket.AF_INET6
    daemon_threads = True

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


def main():
    threading.Thread(target=self_test, name="self-test", daemon=True).start()
    server = DualStackServer(("::", PORT), Handler)
    log("listening", port=PORT, max_bytes=MAX_BYTES,
        watchdog_limit_seconds=WATCHDOG_LIMIT_S)
    server.serve_forever()


if __name__ == "__main__":
    main()
