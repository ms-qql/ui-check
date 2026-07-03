# data/ — Persistente Pipeline-Daten

## `runs.jsonl` — Benchmark-Korpus (append-only, PROJ-4)

`score-report.sh` hängt je Lauf **eine Zeile** an:

```jsonc
{ "date":"2026-07-03", "url_hash":"72745e75dfc5db5e", "industry_tag":"saas",
  "rubric_version":"2026.07-1", "run_id":"…", "total":74,
  "dimensions":{ "visuell":72,"slop":70,"performance":88,"accessibility":82,"conversion":66 } }
```

- **Keine Klardaten:** nur ein 16-stelliger SHA-256-Präfix der finalen URL (`url_hash`) —
  DSGVO-sicher im Repo-Verlauf.
- **Basis für Benchmarks** (PROJ-4 blendet ab n ≥ 10 gleicher `industry_tag` eine
  Vergleichszeile ein) und für Batch-Audits (PROJ-10).
- **Append-only, versioniert:** die Datei wird bewusst committet und wächst über die
  Zeit. `rubric_version` je Zeile hält Benchmarks über Rubrik-Wechsel vergleichbar.
