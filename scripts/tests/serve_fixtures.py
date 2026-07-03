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
  /branding      Seite mit bekanntem Design-System (Farben/Fonts/Radius/Logo) -> Branding-Extraktion
  /brand-logo.png  1x1-PNG (image/png)  -> DOM-Logo-Download
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

# Bekanntes Design-System: primary #1d4ed8, accent #f59e0b, surface #ffffff,
# text #111827, Display-Font Georgia, Text-Font Arial, Radius 12px, Box-Shadow,
# ein AA-Kontrastverstoß (#bbbbbb auf Weiß) und ein DOM-Logo.
BRANDING_EXTRA = (
    '<meta name="description" content="ACME Branding Fixture">'
    "<style>"
    "body{background:#ffffff;color:#111827;font-family:Arial,sans-serif;margin:0}"
    "h1,h2{font-family:Georgia,serif;color:#111827}"
    ".accent{color:#f59e0b}"
    ".btn{background:#1d4ed8;color:#ffffff;border-radius:12px;padding:12px 20px;"
    "box-shadow:0 4px 6px rgba(0,0,0,0.1);border:none;font-size:16px}"
    ".card{background:#f3f4f6;border:1px solid #e5e7eb;border-radius:12px;"
    "padding:24px;margin:16px}"
    ".lowcontrast{color:#bbbbbb;background:#ffffff;font-size:16px}"
    "</style>"
)
BRANDING_BODY = (
    '<header><a href="/"><img class="logo" src="/brand-logo.png" alt="ACME logo"'
    ' width="120" height="40"></a></header>'
    "<main>"
    "<h1>ACME Willkommen</h1>"
    '<h2 class="accent">Unsere Leistungen</h2>'
    "<p>Wir liefern klare, zuverlässige Lösungen für Ihr Unternehmen.</p>"
    '<div class="card"><p>Ein Karten-Element mit Radius und Schatten.</p>'
    '<button class="btn">Jetzt starten</button></div>'
    '<p class="lowcontrast">Schwer lesbarer Hinweistext mit zu geringem Kontrast.</p>'
    "</main><footer><p>© ACME</p></footer>"
)

# 1x1-PNG (transparent), image/png.
import base64
BRAND_LOGO_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
)

# 14 klar unterscheidbare Farbflächen -> Clustering-/Extended-Test (>12 Farben).
_MANY = ["#e11d48", "#db2777", "#c026d3", "#9333ea", "#7c3aed", "#4f46e5",
         "#2563eb", "#0891b2", "#059669", "#16a34a", "#65a30d", "#ca8a04",
         "#ea580c", "#dc2626"]
MANYCOLORS_BODY = "".join(
    f'<div style="background:{c};color:#fff;padding:20px">Block {i}</div>'
    for i, c in enumerate(_MANY)
) + "<p>Abschlusstext für Kontrast.</p>"

# Dunkler Default-Zustand -> dark_mode_hint + Vermerk.
DARKMODE_EXTRA = (
    "<style>body{background:#0a0a0a;color:#e5e7eb;font-family:Arial}"
    "a{color:#60a5fa}</style>"
)
DARKMODE_BODY = (
    "<header><h1>Dunkles Design</h1></header>"
    "<main><p>Heller Text auf dunklem Grund.</p>"
    '<a href="/x">Ein Link</a></main>'
)

# Nur Inline-SVG-Logo im Header, kein <img> -> DOM-SVG-Pfad.
SVGLOGO_BODY = (
    '<header><a href="/"><svg class="logo" width="120" height="40" '
    'viewBox="0 0 120 40" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="120" height="40" fill="#1d4ed8"></rect>'
    '<text x="10" y="26" fill="#fff">ACME</text></svg></a></header>'
    "<main><h1>Seite mit SVG-Logo</h1><p>Etwas Inhalt hier.</p></main>"
)


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
        elif p == "/branding":
            self._html(200, "ACME Branding", BRANDING_BODY, BRANDING_EXTRA)
        elif p == "/manycolors":
            self._html(200, "Viele Farben", MANYCOLORS_BODY)
        elif p == "/darkmode":
            self._html(200, "Dark Mode", DARKMODE_BODY, DARKMODE_EXTRA)
        elif p == "/svglogo":
            self._html(200, "SVG Logo", SVGLOGO_BODY)
        elif p == "/brand-logo.png":
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(BRAND_LOGO_PNG)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(BRAND_LOGO_PNG)
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
