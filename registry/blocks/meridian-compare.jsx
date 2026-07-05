import React from "react";
import { DispatchBar } from "../lib/meridian-ui.jsx";

/*
 * meridian-compare — „us vs them"-Vergleich: zwei Display-Titel (them durchgestrichen)
 * über sieben Zeilen mit Kategorie · eigener Wert · Legacy-Wert.
 * Section-Typ: comparison.  Keine Bild-Slots.
 * Props: { data } — Felder: barLeft/Center/Right, usLabel, themLabel, us, them, rows[].
 */
export default function MeridianCompare({ data = {} }) {
  const { id = "compare", barLeft, barCenter, barRight, usLabel, themLabel, us, them, rows = [] } = data;
  return (
    <section id={id} className="section-padding pt-4">
      <DispatchBar left={barLeft} center={barCenter} right={barRight} />

      <div className="container-x pt-14">
        <div className="grid grid-cols-[3rem_1fr_1fr] items-end gap-4">
          <div />
          <div>
            <div className="mono-label text-paper/40">{usLabel}</div>
            <div className="display mt-2 text-[clamp(2rem,5vw,3.5rem)] text-paper">{us}</div>
          </div>
          <div className="text-right">
            <div className="mono-label text-paper/40">{themLabel}</div>
            <div className="display mt-2 text-[clamp(2rem,5vw,3.5rem)] text-muted line-through decoration-paper/30 decoration-1">{them}</div>
          </div>
        </div>

        <div className="mt-10 border-t border-paper/15">
          {rows.map((r) => (
            <div key={r.n} className="grid grid-cols-[3rem_1fr_1fr] items-center gap-4 border-b border-paper/12 py-6">
              <div className="mono-label text-paper/30">{r.n}</div>
              <div className="flex flex-col gap-3 border-r border-paper/12 pr-4 sm:flex-row sm:items-baseline sm:gap-6">
                <span className="w-28 shrink-0 text-base text-paper/85">{r.cat}</span>
                <span className="font-display text-xl font-medium text-paper md:text-2xl">{r.us}</span>
              </div>
              <div className="font-display pl-4 text-xl font-medium text-muted md:text-2xl">{r.them}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
