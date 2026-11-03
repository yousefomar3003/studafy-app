#!/usr/bin/env python3
"""DL-078 document converter: an authenticated HTTP front for LibreOffice.

Speaks the HttpDocumentConverter contract
(packages/infrastructure/src/documentConverter.ts):

    POST /convert?from=<doc|docx|xls|xlsx|csv|ppt|pptx>&to=<pdf|docx|xlsx|pptx>
                 Authorization: Bearer <CONVERTER_API_KEY>, body = the file
                 200 the converted bytes, with their content type
                 422 {"error": "<code>"}  this file could not be converted
                     (conversion_failed, conversion_timeout, no_output,
                     output_too_large)
                 400 an unknown or unsupported pair of types
                 401 / 411 / 413 / 503 (busy or not ready): retried by the
                     worker, never treated as a conversion
    GET /healthz 200 once the startup self-test converted a CSV to a PDF

Isolation, in layers:
  - its own Fly app with no public service: only the worker reaches it, over
    Fly's private network (fly.converter.test.toml);
  - the server and LibreOffice run as the unprivileged `converter` user, and
    the entrypoint blocks that user's new outbound connections when the
    machine allows it (entrypoint.sh), so a document cannot call out;
  - one conversion at a time, each in a fresh temporary directory with a
    fresh LibreOffice profile (-env:UserInstallation), deleted afterwards,
    so nothing one document leaves behind is seen by the next;
  - the profile turns macros off (security level "very high" and macro
    execution disabled), never updates links to other files or the web,
    never recalculates a workbook on load (cached values are shown), takes
    no locks and checks for no updates - see PROFILE below;
  - each conversion is killed, with every process it started, after
    TIMEOUT_SECONDS; request and result sizes are capped (MAX_BYTES,
    MAX_OUTPUT_BYTES).

Only files the scan already cleared reach here (macros, embedded objects,
external links and passwords are refused at upload), so these are a second
line. Standard library only. Logs are one JSON line per event with types,
sizes, durations and a code - never file contents (no names are sent).
"""

import hmac
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

PORT = int(os.environ.get("PORT", "8080"))
MAX_BYTES = int(os.environ.get("MAX_BYTES", str(25 * 1024 * 1024)))
MAX_OUTPUT_BYTES = int(os.environ.get("MAX_OUTPUT_BYTES", str(25 * 1024 * 1024)))
TIMEOUT_SECONDS = int(os.environ.get("TIMEOUT_SECONDS", "90"))
# How long a request waits for the one conversion slot before 503 (busy).
LOCK_WAIT_SECONDS = int(os.environ.get("LOCK_WAIT_SECONDS", "45"))
SOFFICE = os.environ.get("SOFFICE_BIN", "/usr/bin/soffice")
CHUNK_BYTES = 64 * 1024
API_KEY = os.environ.get("CONVERTER_API_KEY", "")

# The pairs converted. A binary Office file becomes its OOXML twin (for the
# material reader); anything becomes a PDF (the in-app preview).
SOURCES = ("doc", "docx", "xls", "xlsx", "csv", "ppt", "pptx")
OOXML_TWIN = {"doc": "docx", "xls": "xlsx", "ppt": "pptx"}
FILTERS = {
    "pdf": "pdf",
    "docx": "docx:MS Word 2007 XML",
    "xlsx": "xlsx:Calc MS Excel 2007 XML",
    "pptx": "pptx:Impress MS PowerPoint 2007 XML",
}
CONTENT_TYPES = {
    "pdf": "application/pdf",
    "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
}


def supported(source, target):
    if source not in SOURCES:
        return False
    if target == "pdf":
        return True
    return OOXML_TWIN.get(source) == target


def _prop(path, name, value, kind="int"):
    if kind == "bool":
        value = "true" if value else "false"
    return ('<item oor:path="%s"><prop oor:name="%s" oor:op="fuse">'
            '<value>%s</value></prop></item>' % (path, name, value))


SCRIPTING = "/org.openoffice.Office.Common/Security/Scripting"
# The settings every conversion's fresh profile starts with.
PROFILE = "\n".join([
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<oor:items xmlns:oor="http://openoffice.org/2001/registry"'
    ' xmlns:xs="http://www.w3.org/2001/XMLSchema"'
    ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">',
    # Macro security "very high" (3): only macros from trusted locations,
    # and there are none. Macro execution off altogether, on top.
    _prop(SCRIPTING, "MacroSecurityLevel", 3),
    _prop(SCRIPTING, "DisableMacrosExecution", True, "bool"),
    # No links followed from a document to elsewhere when opened, and
    # active content (OLE, DDE) disabled where this version knows the key.
    _prop(SCRIPTING, "BlockUntrustedRefererLinks", True, "bool"),
    _prop(SCRIPTING, "DisableActiveContent", True, "bool"),
    # Links to other files and the web: never updated (1 = never).
    _prop("/org.openoffice.Office.Writer/Content/Update", "Link", 1),
    _prop("/org.openoffice.Office.Calc/Content/Update", "Link", 1),
    # Workbooks are shown with their saved values: no recalculation on load
    # (1 = never), so no formula fetches anything.
    _prop("/org.openoffice.Office.Calc/Formula/Load", "OOXMLRecalcMode", 1),
    _prop("/org.openoffice.Office.Calc/Formula/Load", "ODFRecalcMode", 1),
    # No lock files, no first-start wizard, no update checks.
    _prop("/org.openoffice.Office.Common/Misc", "UseLocking", False, "bool"),
    _prop("/org.openoffice.Office.Common/Misc", "FirstRun", False, "bool"),
    _prop("/org.openoffice.Office.Jobs/Jobs/"
          "org.openoffice.Office.Jobs:Job['UpdateCheck']/Arguments",
          "AutoCheckEnabled", False, "bool"),
    "</oor:items>",
    "",
])


def log(event, **fields):
    print(json.dumps({"event": event, **fields}), flush=True)


def sniff_csv_separator(head):
    """Comma, semicolon or tab: whichever the first line has most of,
    outside quotes. Comma when there is no telling."""
    line = head.split(b"\n", 1)[0]
    counts = {b",": 0, b";": 0, b"\t": 0}
    quoted = False
    for byte in line:
        char = bytes([byte])
        if char == b'"':
            quoted = not quoted
        elif not quoted and char in counts:
            counts[char] += 1
    best = max(counts, key=lambda c: (counts[c], c == b","))
    return {b",": 44, b";": 59, b"\t": 9}[best]


class ConversionError(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


conversion_slot = threading.Lock()


def convert_file(input_path, source, target, workdir):
    """Converts input_path in workdir (which the caller deletes). Returns the
    output path; raises ConversionError with a short code."""
    profile = os.path.join(workdir, "profile")
    os.makedirs(os.path.join(profile, "user"), mode=0o700)
    with open(os.path.join(profile, "user", "registrymodifications.xcu"),
              "w", encoding="utf-8") as handle:
        handle.write(PROFILE)
    outdir = os.path.join(workdir, "out")
    os.mkdir(outdir, 0o700)
    command = [
        SOFFICE,
        "-env:UserInstallation=file://" + profile,
        "--headless", "--invisible", "--nologo", "--nodefault",
        "--nofirststartwizard", "--nolockcheck", "--norestore",
    ]
    if source == "csv":
        with open(input_path, "rb") as handle:
            separator = sniff_csv_separator(handle.read(64 * 1024))
        # Separator, '"' as the text delimiter, UTF-8 (76), from line 1.
        command.append("--infilter=CSV:%d,34,76,1" % separator)
    command += ["--convert-to", FILTERS[target], "--outdir", outdir, input_path]
    environment = {
        "PATH": "/usr/local/bin:/usr/bin:/bin",
        "HOME": workdir,
        "TMPDIR": workdir,
        "LANG": "C.UTF-8",
        # Headless rendering, no display.
        "SAL_USE_VCLPLUGIN": "svp",
    }
    process = subprocess.Popen(
        command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, env=environment, cwd=workdir,
        start_new_session=True)
    try:
        try:
            process.wait(timeout=TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            raise ConversionError("conversion_timeout")
    finally:
        # The whole process group: soffice starts helpers of its own.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        process.wait()
    stem = os.path.splitext(os.path.basename(input_path))[0]
    output = os.path.join(outdir, stem + "." + target)
    if not os.path.isfile(output):
        raise ConversionError(
            "conversion_failed" if process.returncode else "no_output")
    if os.path.getsize(output) > MAX_OUTPUT_BYTES:
        raise ConversionError("output_too_large")
    if os.path.getsize(output) == 0:
        raise ConversionError("no_output")
    return output


self_test_passed = threading.Event()


def self_test():
    """Proves LibreOffice converts before the machine reports healthy: a
    two-line CSV, with Arabic, to a PDF. A converter that cannot must not
    serve: exit, and the machine restarts."""
    workdir = tempfile.mkdtemp(prefix="selftest-")
    try:
        path = os.path.join(workdir, "input.csv")
        with open(path, "wb") as handle:
            handle.write("Name,Score\nلينا,18\n".encode("utf-8"))
        with conversion_slot:
            output = convert_file(path, "csv", "pdf", workdir)
        with open(output, "rb") as handle:
            if handle.read(5) != b"%PDF-":
                raise ConversionError("not_pdf")
    except Exception as error:  # noqa: BLE001 - any failure is fatal here
        log("selftest_failed", reason=getattr(error, "code", type(error).__name__))
        os._exit(1)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)
    self_test_passed.set()
    log("selftest_ok")


class Handler(BaseHTTPRequestHandler):
    server_version = "studafy-converter"
    sys_version = ""
    protocol_version = "HTTP/1.1"
    # Seconds a slow client may take to send its request.
    timeout = 60

    def log_message(self, format, *args):
        pass  # one structured line per request instead

    def respond(self, status, body=None, payload=None, content_type=None):
        if payload is None:
            payload = json.dumps(body).encode() if body is not None else b""
            content_type = "application/json"
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        if self.close_connection:
            self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(payload)

    def refuse(self, status, code, **fields):
        self.close_connection = True
        self.respond(status, {"error": code})
        log("convert_refused", status=status, code=code, **fields)

    def do_GET(self):
        if self.path != "/healthz":
            self.respond(404, {"error": "not_found"})
            return
        healthy = self_test_passed.is_set()
        self.respond(200 if healthy else 503, {"ok": healthy})

    def do_POST(self):
        parts = urlsplit(self.path)
        if parts.path != "/convert":
            self.refuse(404, "not_found")
            return
        provided = self.headers.get("Authorization", "").encode()
        if not hmac.compare_digest(provided, ("Bearer " + API_KEY).encode()):
            self.refuse(401, "unauthorized")
            return
        query = parse_qs(parts.query, keep_blank_values=True)
        source = query.get("from", [None])
        target = query.get("to", [None])
        if (len(source) != 1 or len(target) != 1
                or not supported(source[0], target[0])
                or set(query) - {"from", "to"}):
            self.refuse(400, "unsupported_conversion")
            return
        source, target = source[0], target[0]
        try:
            length = int(self.headers.get("Content-Length"))
        except (TypeError, ValueError):
            length = -1
        if length < 0:
            self.refuse(411, "length_required")
            return
        if length == 0 or length > MAX_BYTES:
            self.refuse(413, "too_large", bytes=length)
            return
        if not self_test_passed.is_set():
            self.refuse(503, "not_ready")
            return

        started = time.monotonic()
        workdir = tempfile.mkdtemp(prefix="convert-")
        try:
            input_path = os.path.join(workdir, "input." + source)
            remaining = length
            with open(input_path, "wb") as handle:
                while remaining > 0:
                    chunk = self.rfile.read(min(CHUNK_BYTES, remaining))
                    if not chunk:
                        self.refuse(400, "body_incomplete")
                        return
                    handle.write(chunk)
                    remaining -= len(chunk)
            if not conversion_slot.acquire(timeout=LOCK_WAIT_SECONDS):
                self.refuse(503, "busy")
                return
            try:
                output = convert_file(input_path, source, target, workdir)
            finally:
                conversion_slot.release()
            with open(output, "rb") as handle:
                payload = handle.read()
        except ConversionError as error:
            self.close_connection = True
            self.respond(422, {"error": error.code})
            log("convert", outcome="refused", code=error.code, source=source,
                target=target, bytes_in=length,
                ms=round((time.monotonic() - started) * 1000))
            return
        except Exception:  # noqa: BLE001 - never a half answer
            self.refuse(503, "internal")
            return
        finally:
            shutil.rmtree(workdir, ignore_errors=True)
        self.respond(200, payload=payload, content_type=CONTENT_TYPES[target])
        log("convert", outcome="ok", source=source, target=target,
            bytes_in=length, bytes_out=len(payload),
            ms=round((time.monotonic() - started) * 1000))

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
    if len(API_KEY) < 32:
        print("converter: CONVERTER_API_KEY is missing or shorter than 32 "
              "characters", file=sys.stderr, flush=True)
        sys.exit(1)
    threading.Thread(target=self_test, name="self-test", daemon=True).start()
    server = DualStackServer(("::", PORT), Handler)
    log("listening", port=PORT, max_bytes=MAX_BYTES,
        max_output_bytes=MAX_OUTPUT_BYTES, timeout_seconds=TIMEOUT_SECONDS)
    server.serve_forever()


if __name__ == "__main__":
    main()
