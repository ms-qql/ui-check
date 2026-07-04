import React from "react";
import { Button, DispatchBar } from "../lib/meridian-ui.jsx";

/*
 * meridian-bulletin — Dispatch-Bar + zweifarbige Headline links, drei
 * Kennzahlen rechts (mittlere invertiert), Fuß-Band mit zwei CTAs.
 * Section-Typ: stats.  Keine Bild-Slots.
 * Props: { data } — Felder: barLeft/Center/Right, kicker, title[], body, footLabel, footMuted, ctas[], stats[].
 */
export default function MeridianBulletin({ data = {} }) {
  const { id = "bulletin", barLeft, barCenter, barRight, kicker, title = [], body, footLabel, footMuted, ctas = [], stats = [] } = data;
  return (
    <section id={id} className="border-y border-paper/12">
      <DispatchBar left={barLeft} center={barCenter} right={barRight} dotted />

      <div className="container-x grid gap-0 lg:grid-cols-2">
        <div className="py-16 lg:pr-16">
          <div className="mono-label text-paper/40">{kicker}</div>
          <h2 className="display mt-6 text-[clamp(2.5rem,5.5vw,4.25rem)]">
            <span className="text-paper">{title[0]} </span>
            <span className="text-muted">{title.slice(1).join(" ")}</span>
          </h2>
          <p className="mt-8 max-w-md text-lg leading-relaxed text-muted">{body}</p>
        </div>

        <div className="grid grid-rows-3 border-paper/12 lg:border-l">
          {stats.map((s, i) => (
            <div key={i} className={`flex flex-col justify-center px-8 py-12 ${s.invert ? "bg-paper text-ink" : "text-paper"} ${i > 0 && !s.invert && !stats[i - 1].invert ? "border-t border-paper/12" : ""}`}>
              <div className="font-display text-[clamp(3.5rem,7vw,6rem)] font-light leading-none">{s.value}</div>
              <div className={`mono-label mt-4 ${s.invert ? "text-ink/50" : "text-paper/45"}`}>{s.label}</div>
            </div>
          ))}
        </div>
      </div>

      <div className="relative border-t border-paper/12">
        <div aria-hidden className="dot-grid absolute inset-0 text-paper/20 opacity-30" />
        <div className="container-x relative flex flex-col items-start justify-between gap-6 py-7 md:flex-row md:items-center">
          <div className="font-display text-lg font-medium">
            <span className="text-paper">{footLabel} </span><span className="text-muted">{footMuted}</span>
          </div>
          <div className="flex items-center gap-6">
            {ctas.map((c) => <Button key={c.label} variant={c.variant} glow={c.glow}>{c.label}</Button>)}
          </div>
        </div>
      </div>
    </section>
  );
}
