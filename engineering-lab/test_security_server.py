#!/usr/bin/env python3
"""Direct HTTP security regression tests for the isolated reviewer static server.

Loopback-only ephemeral port, no user state, no AWS/Docker/libvirt commands.
"""
from __future__ import annotations

import http.client
import threading
import unittest
from http.server import ThreadingHTTPServer

from serve import LabHandler, PUBLIC_FILES


class StaticServerSecurity(unittest.TestCase):
    def setUp(self) -> None:
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), LabHandler)
        self.port = self.server.server_address[1]
        self.worker = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.worker.start()

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.worker.join(timeout=5)

    def request(self, method: str, path: str, headers: dict | None = None):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=4)
        h = {"Host": f"127.0.0.1:{self.port}"}
        if headers:
            h.update(headers)
        conn.request(method, path, headers=h)
        res = conn.getresponse()
        result = res.status, dict(res.getheaders()), res.read()
        conn.close()
        return result

    def test_root_is_html_not_directory_listing(self) -> None:
        status, headers, data = self.request("GET", "/")
        self.assertEqual(status, 200)
        self.assertIn(b"<!doctype html>", data.lower())
        self.assertNotIn(b"Directory listing for", data)
        self.assertIn("default-src 'none'", headers["Content-Security-Policy"])

    def test_only_expected_static_assets_are_readable(self) -> None:
        for path in sorted(PUBLIC_FILES - {"/"}):
            with self.subTest(path=path):
                self.assertEqual(self.request("GET", path)[0], 200)

    def test_sensitive_repo_paths_are_denied(self) -> None:
        for path in (
            "/.git/config", "/../README.md", "/README.md", "/serve.py",
            "/test_engineering_lab.py", "/test_security_server.py",
            "/.terraform/terraform.tfstate", "/terraform.tfstate",
            "/%2e%2e/README.md", "//etc/passwd", "/index.html?file=../README.md",
        ):
            with self.subTest(path=path):
                self.assertNotEqual(self.request("GET", path)[0], 200)
                self.assertNotEqual(self.request("HEAD", path)[0], 200)

    def test_dns_rebinding_and_cross_origin_are_blocked(self) -> None:
        self.assertEqual(self.request("GET", "/", {"Host": "attacker.invalid"})[0], 400)
        self.assertEqual(self.request("GET", "/", {"Origin": "https://attacker.invalid"})[0], 403)

    def test_read_only_methods_and_no_cache(self) -> None:
        status, headers, _ = self.request("GET", "/missions.json")
        self.assertEqual(status, 200)
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertEqual(headers["X-Frame-Options"], "DENY")
        self.assertEqual(self.request("POST", "/")[0], 501)


if __name__ == "__main__":
    unittest.main()
