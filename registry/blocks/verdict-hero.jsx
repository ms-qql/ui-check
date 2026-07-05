import React from "react";
import { Button, Slot } from "../lib/ui.jsx";

/*
 * verdict-hero — dunkler Full-Bleed-Foto-Hero mit Kennzahlen-Leiste.
 * Section-Typ: hero.  Bild-Slots: hero-visual.
 * Props: { data } aus content.json (Sektion mit type "hero").
 */
export default function VerdictHero({ data = {} }) {
  const { id = "hero", eyebrow, title, bullets = [], ctas = [], trustedBy, avatarCount = 4, stats = [], imageSlot = "hero-visual" } = data;
  return (
    <section id={id} className="relative flex min-h-[max(100svh,800px)] flex-col overflow-hidden bg-ink text-paper">
      {/* Full-Bleed-Bild rechts + Verlauf nach links */}
      <Slot id={imageSlot} dark className="absolute inset-0" imgClass="object-right" src={data.image}>
        <div className="absolute inset-0 bg-gradient-to-r from-ink via-ink/80 to-ink/20" />
        <div className="absolute inset-0 bg-gradient-to-t from-ink via-transparent to-ink/40" />
      </Slot>

      <div className="container-x relative flex flex-1 flex-col pt-40">
        {eyebrow && (
          <div className="mono-label flex items-center gap-3 text-paper/70">
            <span aria-hidden>⟶</span> {eyebrow}
          </div>
        )}
        <h1 className="display mt-6 max-w-3xl text-[clamp(2.75rem,6vw,5rem)]">{title}</h1>

        {bullets.length > 0 && (
          <ul className="mt-8 space-y-3 text-lg text-paper/85">
            {bullets.map((b) => (
              <li key={b} className="flex items-center gap-3">
                <span className="h-1.5 w-1.5 rounded-full bg-paper/60" /> {b}
              </li>
            ))}
          </ul>
        )}

        {ctas.length > 0 && (
          <div className="mt-10 flex flex-wrap gap-3">
            {ctas.map((c) => (
              <Button key={c.label} size="lg" variant={c.variant || "invert"}>{c.label}</Button>
            ))}
          </div>
        )}

        {/* Trusted-by + Kennzahlen */}
        <div className="mt-auto flex flex-col gap-8 border-t border-paper/10 py-8 md:flex-row md:items-end md:justify-between">
          <div className="flex items-center gap-4">
            <div className="flex -space-x-3">
              {Array.from({ length: avatarCount }).map((_, i) => (
                <span key={i} className="h-10 w-10 rounded-full border-2 border-ink bg-surface" />
              ))}
            </div>
            {trustedBy && <div className="mono-label text-paper/50">{trustedBy}</div>}
          </div>
          {stats.length > 0 && (
            <div className="grid grid-cols-3 gap-8">
              {stats.map((s) => (
                <div key={s.label}>
                  <div className="text-2xl font-medium md:text-3xl">{s.value}</div>
                  <div className="mt-1 text-sm text-paper/60">{s.label}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
