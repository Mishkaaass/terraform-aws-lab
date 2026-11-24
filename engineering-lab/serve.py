#!/usr/bin/env python3
"""Local, read-only allowlist HTTP server for the Infrastructure Failure Lab.

Never serve the repository root: it may contain .git, .terraform and tfstate.
This process has no AWS, Docker or libvirt privileges and never runs commands.
"""
from __future__ import annotations

import argparse
from functools import partial
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
PUBLIC_FILES = frozenset({"/", "/index.html", "/app.js", "/style.css", "/missions.json"})
CSP = (
    "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; "
    "img-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'; "
    "frame-ancestors 'none'"
)


class LabHandler(SimpleHTTPRequestHandler):
    """Serve exactly four static assets, without directory listing or traversal."""

    server_version = "InfrastructureLab"
    sys_version = ""
    protocol_version = "HTTP/1.0"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self) -> None:
        for name, value in (
            ("Content-Security-Policy", CSP),
            ("X-Content-Type-Options", "nosniff"),
            ("X-Frame-Options", "DENY"),
            ("Referrer-Policy", "no-referrer"),
            ("Cross-Origin-Resource-Policy", "same-origin"),
            ("Cross-Origin-Opener-Policy", "same-origin"),
            ("Cache-Control", "no-store"),
        ):
            self.send_header(name, value)
        super().end_headers()

    def _authorized_path(self) -> bool:
        port = self.server.server_address[1]
        hosts = self.headers.get_all("Host", [])
        if len(hosts) != 1 or hosts[0] not in (
            f"127.0.0.1:{port}", f"localhost:{port}"
        ):
            self.send_error(HTTPStatus.BAD_REQUEST, "Invalid Host header")
            return False
        origin = self.headers.get("Origin")
        if origin and origin not in (
            f"http://127.0.0.1:{port}", f"http://localhost:{port}"
        ):
            self.send_error(HTTPStatus.FORBIDDEN, "Invalid Origin header")
            return False
        parsed = urlsplit(self.path)
        if parsed.path not in PUBLIC_FILES or parsed.query or parsed.fragment:
            self.send_error(HTTPStatus.NOT_FOUND, "Not a public lab asset")
            return False
        return True

    def _serve_static(self, *, send_body: bool) -> None:
        if not self._authorized_path():
            return
        # Never delegate "/" to SimpleHTTPRequestHandler's directory listing.
        if self.path == "/":
            self.path = "/index.html"
        if send_body:
            super().do_GET()
        else:
            super().do_HEAD()

    def do_GET(self) -> None:
        self._serve_static(send_body=True)

    def do_HEAD(self) -> None:
        self._serve_static(send_body=False)

    def log_message(self, fmt: str, *args: object) -> None:
        # Do not write raw URL paths or request headers to the terminal.
        return


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve only public Engineering Lab assets on localhost")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("Port must be 1024-65535")
    try:
        with ThreadingHTTPServer(("127.0.0.1", args.port), LabHandler) as httpd:
            print(f"Infrastructure Failure Lab: http://127.0.0.1:{args.port}/", flush=True)
            print("Only the four public UI assets can be served. Ctrl+C stops.", flush=True)
            httpd.serve_forever(poll_interval=0.4)
    except OSError as error:
        parser.exit(1, f"Unable to bind the local server: {error}\n")
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
