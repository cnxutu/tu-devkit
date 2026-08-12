#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import io
import tempfile
import threading
import urllib.error
import urllib.request
from contextlib import redirect_stderr
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "clash_remote_server", ROOT / "scripts" / "clash-remote-server.py"
)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory() as directory:
    profile = Path(directory) / "vps-clash.yaml"
    content = b"proxies:\n  - name: test\n    type: ss\n"
    profile.write_bytes(content)
    token = "0123456789abcdef" * 3
    server = module.build_server("127.0.0.1", 0, token, profile, 24)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    port = server.server_address[1]
    url = f"http://127.0.0.1:{port}/subscription/{token}/vps-clash.yaml"
    request_log = io.StringIO()
    with redirect_stderr(request_log):
        with urllib.request.urlopen(url) as response:
            assert response.status == 200
            assert response.read() == content
            assert response.headers["Profile-Update-Interval"] == "24"
            assert response.headers["Content-Disposition"] == 'attachment; filename="vps-clash.yaml"'
            assert response.headers["Cache-Control"] == "no-store"
        for path in (
            "/",
            "/subscription/wrong/vps-clash.yaml",
            f"/subscription/{token}/vps-clash.yaml?unexpected=true",
        ):
            try:
                urllib.request.urlopen(f"http://127.0.0.1:{port}{path}")
                raise AssertionError(f"unexpected success for {path}")
            except urllib.error.HTTPError as error:
                assert error.code == 404
    assert request_log.getvalue() == ""
    server.shutdown(); server.server_close(); thread.join(timeout=2)

print("vps-init Clash Remote server test passed")
