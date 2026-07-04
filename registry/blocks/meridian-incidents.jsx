import React from "react";
import { DispatchBar } from "../lib/meridian-ui.jsx";
import { cn } from "../lib/cn.js";

/*
 * meridian-incidents — „What failed / what held": asymmetrische Doppel-Headline
 * + Incident-Log-Tabelle mit Mini-Sparklines (Peak-Zeile rot hervorgehoben).
 * Section-Typ: log-table.  Keine Bild-Slots.
 * Props: { data } — Felder: barLeft/Center/Right, titleA[], titleB[], brand, stepLabel, body, cols[], rows[], footL/C/R.
 */
function Spark({ peak }) {
  const pts = peak ? "0,9 8,8 14,3 18,10 22,1 28,9 40,8" : "0,9 10,8 16,6 20,9 26,7 32,9 40,8";
  return (
    <svg viewBox="0 0 40 12" className="h-3 w-16 text-paper/50" fill="none" stroke="currentColor" strokeWidth="1">
      <polyline points={pts} />
    </svg>
  );
}

export default function MeridianIncidents({ data = {} }) {
  const { id = "incidents", barLeft, barCenter, barRight, titleA = [], titleB = [], brand, stepLabel, body, cols = [], rows = [], footL, footC, footR } = data;
  return (
    <section id={id} className="relative isolate overflow-hidden">
      <DispatchBar left={barLeft} center={barCenter} right={barRight} />

      <div className="container-x pt-16">
        <h2 className="display text-[clamp(2.5rem,6vw,5rem)]">
          <span className="text-paper">{titleA[0]} </span><span className="text-muted">{titleA[1]}</span>
        </h2>
        <div className="mt-2 flex items-baseline justify-end gap-6">
          <span className="mono-label text-paper/30">{brand}</span>
          <span className="display text-[clamp(2.5rem,6vw,5rem)]">
            <span className="text-muted">{titleB[0]} </span><span className="text-paper">{titleB[1]}</span>
          </span>
        </div>

        <div className="mt-10 grid gap-8 md:grid-cols-2">
          <div className="mono-label text-paper/40">{stepLabel}</div>
          <p className="max-w-lg leading-relaxed text-muted">{body}</p>
        </div>

        <div className="mt-14">
          <div className="mono-label grid grid-cols-[5rem_3rem_5rem_3rem_1fr_auto] items-center gap-4 border-b border-paper/12 pb-3 text-paper/35">
            {cols.map((c, i) => <span key={c} className={i === cols.length - 1 ? "text-right" : ""}>{c}</span>)}
          </div>
          {rows.map((r, i) => (
            <div key={i} className={cn("grid grid-cols-[5rem_3rem_5rem_3rem_1fr_auto] items-center gap-4 border-b border-paper/8 py-4", r.peak && "bg-paper/[0.04]")}>
              <span className="mono-label text-paper/60">{r.t}</span>
              <span className="mono-label text-paper/40">{r.d}</span>
              <Spark peak={r.peak} />
              <span className={cn("font-display text-2xl font-light", r.peak ? "text-accent" : "text-paper")}>{r.mag}</span>
              <span className="mono-label text-paper/70">{r.where}</span>
              <span className="mono-label text-right text-paper/40">{r.note}</span>
            </div>
          ))}
        </div>

        <div className="mono-label flex justify-between py-8 text-paper/30">
          <span>{footL}</span><span className="hidden md:block">{footC}</span><span>{footR}</span>
        </div>
      </div>
    </section>
  );
}
