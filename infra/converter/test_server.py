"""Unit tests for the document converter's HTTP front (DL-078).

LibreOffice is replaced by a stand-in script, so this runs anywhere with
Python 3.9+: python3 -m unittest discover -s infra/converter
"""

import http.client
import importlib
import json
import os
import stat
import sys
import tempfile
import threading
import time
import unittest

KEY = "synthetic-converter-key-" + "0" * 16
FAKE = r'''#!/usr/bin/env python3
import json, os, sys, time
args = sys.argv[1:]
outdir = args[args.index("--outdir") + 1]
source = args[-1]
target = args[args.index("--convert-to") + 1].split(":")[0]
profile = [a for a in args if a.startswith("-env:UserInstallation=file://")][0]
profile = profile[len("-env:UserInstallation=file://"):]
with open(os.path.join(profile, "user", "registrymodifications.xcu")) as f:
    settings = f.read()
with open(source, "rb") as f:
    body = f.read()
if b"SLEEP" in body:
    time.sleep(30)
if b"FAIL" in body:
    sys.exit(1)
stem = os.path.splitext(os.path.basename(source))[0]
with open(os.path.join(outdir, stem + "." + target), "wb") as f:
    f.write(b"%PDF-fake " + json.dumps({
        "args": args,
        "macros_off": "MacroSecurityLevel" in settings,
        "home": os.environ.get("HOME"),
    }).encode())
'''


def setUpModule():
    global server, fake_dir
    fake_dir = tempfile.mkdtemp(prefix="fake-soffice-")
    fake = os.path.join(fake_dir, "soffice")
    with open(fake, "w") as handle:
        handle.write(FAKE.replace("/usr/bin/env python3", sys.executable, 1))
    os.chmod(fake, stat.S_IRWXU)
    os.environ.update({
        "CONVERTER_API_KEY": KEY,
        "SOFFICE_BIN": fake,
        "TIMEOUT_SECONDS": "2",
        "LOCK_WAIT_SECONDS": "1",
        "MAX_BYTES": "4096",
    })
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    server = importlib.import_module("server")


class ConverterTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        server.self_test()  # exits the process if the stand-in fails
        cls.httpd = server.ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.port = cls.httpd.server_address[1]
        threading.Thread(target=cls.httpd.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()

    def post(self, path, body=b"hello", key=KEY, headers=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=20)
        sent = {"Authorization": "Bearer " + key}
        sent.update(headers or {})
        connection.request("POST", path, body=body, headers=sent)
        response = connection.getresponse()
        data = response.read()
        connection.close()
        return response.status, response.getheader("Content-Type"), data

    def test_health_after_self_test(self):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        connection.request("GET", "/healthz")
        response = connection.getresponse()
        self.assertEqual(response.status, 200)
        self.assertEqual(json.loads(response.read()), {"ok": True})
        connection.close()

    def test_converts_with_a_fresh_locked_down_profile(self):
        status, content_type, data = self.post("/convert?from=docx&to=pdf")
        self.assertEqual(status, 200)
        self.assertEqual(content_type, "application/pdf")
        self.assertTrue(data.startswith(b"%PDF-fake "))
        seen = json.loads(data[len(b"%PDF-fake "):])
        self.assertTrue(seen["macros_off"])
        self.assertIn("--headless", seen["args"])
        self.assertIn("pdf", seen["args"])
        # The work directory, profile included, is gone afterwards.
        self.assertFalse(os.path.exists(seen["home"]))

    def test_binary_office_files_become_their_ooxml_twin(self):
        status, content_type, data = self.post("/convert?from=ppt&to=pptx")
        self.assertEqual(status, 200)
        self.assertEqual(
            content_type,
            "application/vnd.openxmlformats-officedocument.presentationml.presentation")
        args = json.loads(data[len(b"%PDF-fake "):])["args"]
        self.assertIn("pptx:Impress MS PowerPoint 2007 XML", args)

    def test_csv_separator_is_sniffed(self):
        status, _, data = self.post("/convert?from=csv&to=pdf",
                                    body=b'Name;"a;b";Score\nx;y;1\n')
        self.assertEqual(status, 200)
        args = json.loads(data[len(b"%PDF-fake "):])["args"]
        self.assertIn("--infilter=CSV:59,34,76,1", args)
        self.assertEqual(server.sniff_csv_separator(b"a\tb\tc\n"), 9)
        self.assertEqual(server.sniff_csv_separator(b"just text\n"), 44)

    def test_wrong_key_is_refused(self):
        status, _, _ = self.post("/convert?from=doc&to=pdf", key="x" * 40)
        self.assertEqual(status, 401)

    def test_unsupported_pairs_and_extra_parameters_are_refused(self):
        for path in ["/convert?from=doc&to=xlsx", "/convert?from=exe&to=pdf",
                     "/convert?from=doc&to=pdf&to=docx",
                     "/convert?from=doc&to=pdf&path=/etc", "/convert?to=pdf"]:
            status, _, _ = self.post(path)
            self.assertEqual(status, 400, path)
        self.assertEqual(self.post("/scan?from=doc&to=pdf")[0], 404)

    def test_size_limits(self):
        self.assertEqual(self.post("/convert?from=doc&to=pdf",
                                   body=b"x" * 5000)[0], 413)
        self.assertEqual(self.post("/convert?from=doc&to=pdf", body=b"")[0], 413)

    def test_a_failed_conversion_is_422_with_a_code(self):
        status, _, data = self.post("/convert?from=doc&to=pdf", body=b"FAIL")
        self.assertEqual(status, 422)
        self.assertEqual(json.loads(data), {"error": "conversion_failed"})

    def test_a_slow_conversion_is_killed(self):
        started = time.monotonic()
        status, _, data = self.post("/convert?from=xls&to=pdf", body=b"SLEEP")
        self.assertEqual(status, 422)
        self.assertEqual(json.loads(data), {"error": "conversion_timeout"})
        self.assertLess(time.monotonic() - started, 15)

    def test_profile_settings(self):
        for needle in ['"MacroSecurityLevel" oor:op="fuse"><value>3<',
                       '"DisableMacrosExecution" oor:op="fuse"><value>true<',
                       '"OOXMLRecalcMode" oor:op="fuse"><value>1<',
                       "Office.Calc/Content/Update", "Office.Writer/Content/Update",
                       '"AutoCheckEnabled" oor:op="fuse"><value>false<']:
            self.assertIn(needle, server.PROFILE)

    def test_supported_pairs(self):
        self.assertTrue(server.supported("doc", "docx"))
        self.assertTrue(server.supported("csv", "pdf"))
        self.assertFalse(server.supported("docx", "docx"))
        self.assertFalse(server.supported("pdf", "pdf"))


if __name__ == "__main__":
    unittest.main()
