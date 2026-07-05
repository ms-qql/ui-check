import React from "react";
import { Button, DispatchBar } from "../lib/ui.jsx";

export default function Bulletin({ data = {} }) {
  const { barLeft, barCenter, barRight, kicker, title = [], body, footLabel, footMuted, ctas = [], stats = [] } = data;
  return (
    <section id="bulletin" className="border-y border-paper/12">
      <DispatchBar left={barLeft} center={barCenter} right={barRight} dotted />

      <div className="container-x grid gap-0 lg:grid-cols-2">
        {/* Links: Headline */}
        <div className="py-16 lg:pr-16">
          <div className="mono-label text-paper/40">{kicker}</div>
          <h2 className="display mt-6 text-[clamp(2.5rem,5.5vw,4.25rem)]">
            <span className="text-paper">{title[0]} </span>
            <span className="text-muted">{title[1]} {title[2]}</span>
          </h2>
          <p className="mt-8 max-w-md text-lg leading-relaxed text-muted">{body}</p>
        </div>

        {/* Rechts: drei Kennzahlen (mittlere invertiert) */}
        <div className="grid grid-rows-3 border-paper/12 lg:border-l">
          {stats.map((s, i) => (
            <div key={i} className={`flex flex-col justify-center px-8 py-12 ${s.invert ? "bg-paper text-ink" : "text-paper"} ${i > 0 && !s.invert && !stats[i-1].invert ? "border-t border-paper/12" : ""}`}>
              <div className="text-[clamp(3.5rem,7vw,6rem)] font-light leading-none" style={{ fontFamily: "var(--font-display)" }}>{s.value}</div>
              <div className={`mono-label mt-4 ${s.invert ? "text-ink/50" : "text-paper/45"}`}>{s.label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Fuß-Band */}
      <div className="relative border-t border-paper/12">
        <div aria-hidden className="dot-grid absolute inset-0 text-paper/20 opacity-30" />
        <div className="container-x relative flex flex-col items-start justify-between gap-6 py-7 md:flex-row md:items-center">
          <div className="text-lg font-medium" style={{ fontFamily: "var(--font-display)" }}>
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
