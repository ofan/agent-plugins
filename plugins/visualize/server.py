#!/usr/bin/env python3
import http.server, sys, os, json, re, time, socket, mimetypes
from pathlib import Path

BASE_DIR = Path.home() / ".local" / "share" / "claude-visualize"
PAGES_DIR = BASE_DIR / "pages"
PAGES_DIR.mkdir(parents=True, exist_ok=True)
FEEDBACK_DIR = BASE_DIR / "feedback"
FEEDBACK_DIR.mkdir(parents=True, exist_ok=True)
PORT = int(sys.argv[1])

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            self._serve_index()
        elif m := re.match(r"^/_feedback/([A-Za-z0-9_-]+)$", self.path.split("?")[0]):
            fp = FEEDBACK_DIR / (m.group(1) + ".json")
            if fp.is_file():
                self._respond(200, fp.read_bytes(), "application/json")
            else:
                self._respond(404, b"null", "application/json")
        else:
            self._serve_file()

    def do_POST(self):
        # Collect review feedback from the page (Atlas viewer): POST /_feedback/<slug>
        m = re.match(r"^/_feedback/([A-Za-z0-9_-]+)$", self.path.split("?")[0])
        if not m:
            self._respond(404, b'{"ok":false}', "application/json"); return
        length = min(int(self.headers.get("Content-Length", "0")), 512 * 1024)
        raw = self.rfile.read(length)
        try:
            json.loads(raw)  # validate; reject non-JSON
        except Exception:
            self._respond(400, b'{"ok":false}', "application/json"); return
        (FEEDBACK_DIR / (m.group(1) + ".json")).write_bytes(raw)
        self._respond(200, b'{"ok":true}', "application/json")

    def _serve_index(self):
        files = sorted(PAGES_DIR.glob("*.html"), key=lambda f: f.stat().st_mtime, reverse=True)
        items = "".join(
            f'<li><a href="/{f.name}">{f.stem.replace("-", " ").title()}</a> <span style="color:#71747e;font-size:12px">({time.strftime("%H:%M", time.localtime(f.stat().st_mtime))})</span></li>'
            for f in files
        ) if files else '<li style="color:#71747e">No visualizations yet</li>'
        hostname = socket.gethostname()
        html = f"""<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Visualizations</title>
<style>body{{font-family:system-ui;background:#fbfbfd;color:#1b1d22;padding:40px;max-width:600px;margin:auto}}
h1{{font-size:18px;margin-bottom:20px}} a{{color:#4a6cff;text-decoration:none;font-size:16px}} a:hover{{text-decoration:underline}}
li{{margin-bottom:8px}} .hint{{color:#71747e;font-size:13px;margin-top:24px}}</style></head>
<body><h1>Visualizations</h1><ul>{items}</ul><p class="hint">Served on {hostname} — pages from Claude Code /visualize</p></body></html>"""
        self._respond(200, html.encode(), "text/html")

    def _serve_file(self):
        path = self.path.split("?")[0].lstrip("/")
        filepath = PAGES_DIR / path
        if not filepath.exists() or not filepath.is_file():
            self._respond(404, b"Not found", "text/plain")
            return
        content = filepath.read_bytes()
        ct, _ = mimetypes.guess_type(str(filepath))
        self._respond(200, content, ct or "text/html")

    def _respond(self, code, body, ct):
        self.send_response(code)
        self.send_header("Content-Type", ct)
        self.send_header("Content-Length", str(len(body)))
        # Pages are edited in place (same URL); without this the browser serves
        # a heuristically-cached stale copy and updates look like they didn't land.
        self.send_header("Cache-Control", "no-store, must-revalidate")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass

server = http.server.HTTPServer(("0.0.0.0", PORT), Handler)
print(f"SERVER_READY:{PORT}", flush=True)
server.serve_forever()
