# Rubrik: Conversion (Cai-Modell) — Judge-Pass „conversion"

**Version:** siehe `rubrics/VERSION` · **Skala:** fünf Teilscores je **0–100**
**Input:** die drei Screenshots + `snapshot.txt` (A11y-Tree/Copy) aus PROJ-1.
**Dimension `conversion` = arithmetisches Mittel der fünf Teilscores.**

## Auftrag an den Judge

Bewerte die **Überzeugungs-/Conversion-Kraft** der Seite entlang der fünf Cai-Achsen.
Bezugsrahmen ist die primäre Seitenaufgabe: Landing → zur Handlung führen; reine
Info-Seite ohne CTA → **Action** und **Logic** auf die Info-Aufgabe beziehen (nicht mit
0 abstrafen) und `cta_present: false` melden.

| Achse | Frage |
|---|---|
| **Clarity** | Ist in 5 Sekunden klar, worum es geht, für wen, was es bringt? |
| **Credibility** | Vertrauensanker sichtbar? (Logos, Referenzen, Zahlen, Impressum, Fotos, Konsistenz) |
| **Logic** | Trägt der Seitenfluss ein schlüssiges Argument (Problem → Lösung → Beleg → Handlung)? |
| **Action** | Ist der nächste Schritt eindeutig, sichtbar, reibungsarm? (CTA-Klarheit/Position/Anzahl) |
| **Emotion** | Weckt Bildsprache/Ton eine passende, zielgruppengerechte Resonanz? |

## Anker-Bänder (gelten je Achse, 0–100)

| Band | Anker (je Achse sinngemäß anwenden) |
|---|---|
| **0–20** | Achse praktisch nicht erfüllt (z. B. Zweck unklar; kein CTA; keinerlei Vertrauensanker; belangloser Fluss). |
| **21–40** | Schwach: Ansatz vorhanden, aber verwässert (versteckter CTA, dünne Belege, wirre Reihenfolge). |
| **41–60** | Durchschnitt: erfüllt die Achse grundständig, ohne zu überzeugen; generisch. |
| **61–80** | Stark: klar, glaubwürdig, gut geführt; kleine Reibungspunkte. |
| **81–100** | Herausragend: sofort verständlich, überzeugende Belege, zwingende Führung, unwiderstehlicher nächster Schritt. |

## Zusatzsignale an die Pipeline
- `cta_present` (bool): erkennbarer primärer CTA vorhanden?
- `app_mode` (bool): wirkt eher wie eine App/Tool-Oberfläche als eine Landing/Info-Seite (Heuristik aus PROJ-1-Snapshot bestätigen) → Report vermerkt „App-Modus empfohlen".
- `language_confident` (bool): verstehst du die Seitensprache sicher genug für Copy-Befunde?

## Befunde (Pflicht)
Je Befund: **title**, **severity**, **evidence** (welche Achse, was konkret),
**location** (Sektion + Viewport), **source** = `conversion`.
