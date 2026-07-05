import React from "react";
import { hero } from "../content.js";
import { Button } from "../lib/ui.jsx";

export default function Hero() {
  return (
    <section className="relative flex min-h-[max(100svh,800px)] flex-col overflow-hidden bg-neutral-950 text-white">
      {/* Full-bleed Foto rechts + Verlauf nach links */}
      <div className="absolute inset-0">
        <img src={hero.bg} alt="" className="h-full w-full object-cover object-right" />
        <div className="absolute inset-0 bg-gradient-to-r from-neutral-950 via-neutral-950/80 to-neutral-950/20" />
        <div className="absolute inset-0 bg-gradient-to-t from-neutral-950 via-transparent to-neutral-950/40" />
      </div>

      <div className="container-x relative flex flex-1 flex-col pt-40">
        <div className="mono-label flex items-center gap-3 text-white/70">
          <span aria-hidden>⟶</span> {hero.eyebrow}
        </div>
        <h1 className="display mt-6 max-w-3xl text-[clamp(2.75rem,6vw,5rem)]">{hero.title}</h1>

        <ul className="mt-8 space-y-3 text-lg text-white/85">
          {hero.bullets.map((b) => (
            <li key={b} className="flex items-center gap-3">
              <span className="h-1.5 w-1.5 rounded-full bg-white/60" /> {b}
            </li>
          ))}
        </ul>

        <div className="mt-10 flex flex-wrap gap-3">
          {hero.ctas.map((c) => (
            <Button key={c.label} size="lg" variant={c.variant}>{c.label}</Button>
          ))}
        </div>

        {/* Trusted-by + Stats unten */}
        <div className="mt-auto flex flex-col gap-8 border-t border-white/10 py-8 md:flex-row md:items-end md:justify-between">
          <div className="flex items-center gap-4">
            <div className="flex -space-x-3">
              {hero.avatars.map((a, i) => (
                <img key={i} src={a} alt="" className="h-10 w-10 rounded-full border-2 border-neutral-950 object-cover" />
              ))}
            </div>
            <div className="text-sm text-white/70">
              <div className="mono-label text-white/50">{hero.trustedBy}</div>
            </div>
          </div>
          <div className="grid grid-cols-3 gap-8">
            {hero.stats.map((s) => (
              <div key={s.label}>
                <div className="text-2xl font-medium md:text-3xl">{s.value}</div>
                <div className="mt-1 text-sm text-white/60">{s.label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
