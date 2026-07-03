#!/usr/bin/env python3
"""Deterministischer Fixture-Server für die capture.sh-QA.

Startet einen lokalen HTTP-Server, der Testseiten + Sonderrouten ausliefert,
damit die Acceptance Criteria von PROJ-1 ohne Internet-Abhängigkeit und ohne
Flakiness geprüft werden können.

Routen:
  /normal        normale Seite (Sektionen, Meta-Description, OG-Tags, Favicon)
  /tall          ~25.000 px hohe Seite  -> Höhenkappung
  /cookie        Seite mit OneTrust-artigem Banner  -> Cookie-Dismiss
  /spa           leere SPA-Hülle (kein sichtbarer Text)  -> content_suspicion
  /redirect      302 -> /normal  -> Redirect-Kette
  /notfound      HTTP 404
  /doc.pdf       Content-Type application/pdf  -> "Kein HTML-Dokument"
  /botwall       HTTP 403 + Cloudflare-Marker  -> Bot-Schutz

Aufruf:  serve_fixtures.py [port]   (Default 8973)
Der Server schreibt "READY <port>" auf stdout, sobald er lauscht.
"""
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HEAD = """<!doctype html><html lang="de"><head><meta charset="utf-8">
<title>{title}</title>{extra}</head><body>{body}</body></html>"""

NORMAL_EXTRA = (
    '<meta name="description" content="Testseite für UI-Check Capture QA.">'
    '<meta property="og:title" content="UI-Check Normal Fixture">'
    '<meta property="og:type" content="website">'
    '<link rel="icon" href="/favicon.ico">'
)
NORMAL_BODY = (
    "<header><h1>Kopfbereich</h1></header>"
    "<nav>Navigation</nav>"
    "<main><section><h2>Abschnitt 1</h2><p>Viel sichtbarer Text hier für die Analyse.</p></section>"
    "<section><h2>Abschnitt 2</h2><p>Noch mehr Inhalt zum Bewerten.</p></section></main>"
    "<footer>Fußbereich</footer>"
)

TALL_BODY = "".join(
    f'<section style="height:1000px;border-bottom:1px solid #ccc">Block {i}</section>'
    for i in range(26)
)  # ~26.000 px

COOKIE_BODY = (
    '<div id="onetrust-banner-sdk" style="position:fixed;bottom:0;background:#222;color:#fff;padding:20px">'
    'Wir verwenden Cookies. '
    '<button id="onetrust-accept-btn-handler">Alle akzeptieren</button></div>'
    "<main><h1>Inhalt hinter dem Banner</h1><p>Sichtbarer Text der Seite.</p></main>"
)

SPA_BODY = '<div id="root"></div><script>/* rendert nichts */</script>'


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):  # keine Logzeilen ins Test-Output
        pass

    def _html(self, code, title, body, extra=""):
        payload = HEAD.format(title=title, body=body, extra=extra).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        p = self.path.split("?")[0]
        if p in ("/", "/normal"):
            self._html(200, "Normale Testseite", NORMAL_BODY, NORMAL_EXTRA)
        elif p == "/tall":
            self._html(200, "Sehr hohe Seite", TALL_BODY)
        elif p == "/cookie":
            self._html(200, "Seite mit Cookie-Banner", COOKIE_BODY)
        elif p == "/spa":
            self._html(200, "SPA", SPA_BODY)
        elif p == "/redirect":
            self.send_response(302)
            self.send_header("Location", "/normal")
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif p == "/notfound":
            self._html(404, "Nicht gefunden", "<h1>404</h1>")
        elif p == "/doc.pdf":
            body = b"%PDF-1.4 fake pdf body"
            self.send_response(200)
            self.send_header("Content-Type", "application/pdf")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)
        elif p == "/botwall":
            body = (
                b"<!doctype html><html><head><title>Just a moment...</title></head>"
                b"<body><div class='cf-browser-verification'>Checking your browser"
                b" before accessing. cf-chl-bypass</div></body></html>"
            )
            self.send_response(403)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Server", "cloudflare")
            self.send_header("cf-mitigated", "challenge")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)
        else:
            self._html(404, "Nicht gefunden", "<h1>404</h1>")


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8973
    httpd = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"READY {port}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
