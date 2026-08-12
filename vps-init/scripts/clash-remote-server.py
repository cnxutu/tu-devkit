#!/usr/bin/env python3
"""Serve one token-protected Clash profile on a WireGuard address."""

from __future__ import annotations

import argparse
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote, urlsplit


def settings_from_env() -> tuple[str, int, str, Path, int]:
    bind = os.environ["CLASH_REMOTE_BIND"]
    port = int(os.environ["CLASH_REMOTE_PORT"])
    token = os.environ["CLASH_REMOTE_TOKEN"]
    profile = Path(os.environ["CLASH_REMOTE_PROFILE"])
    interval = int(os.environ["CLASH_REMOTE_UPDATE_INTERVAL"])
    if not bind or not 1 <= port <= 65535:
        raise ValueError("invalid bind address or port")
    if len(token) < 32 or any(char not in "0123456789abcdef" for char in token):
        raise ValueError("token must be at least 128-bit lowercase hexadecimal")
    if not profile.is_file() or interval < 1:
        raise ValueError("profile must exist and update interval must be positive")
    return bind, port, token, profile, interval


def build_server(
    bind: str, port: int, token: str, profile: Path, interval: int
) -> ThreadingHTTPServer:
    expected_path = f"/subscription/{quote(token, safe='')}/vps-clash.yaml"

    class ProfileHandler(BaseHTTPRequestHandler):
        def _serve(self, include_body: bool) -> None:
            request_target = urlsplit(self.path)
            if request_target.path != expected_path or request_target.query:
                self.send_error(404)
                return
            try:
                content = profile.read_bytes()
            except OSError:
                self.send_error(503)
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/yaml; charset=utf-8")
            self.send_header(
                "Content-Disposition", 'attachment; filename="vps-clash.yaml"'
            )
            self.send_header("Profile-Update-Interval", str(interval))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            if include_body:
                self.wfile.write(content)

        def do_GET(self) -> None:  # noqa: N802
            self._serve(True)

        def do_HEAD(self) -> None:  # noqa: N802
            self._serve(False)

        def log_message(self, _format: str, *_args: object) -> None:
            return

    return ThreadingHTTPServer((bind, port), ProfileHandler)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-config", action="store_true")
    args = parser.parse_args()
    bind, port, token, profile, interval = settings_from_env()
    if args.check_config:
        return
    server = build_server(bind, port, token, profile, interval)
    server.serve_forever()


if __name__ == "__main__":
    main()
