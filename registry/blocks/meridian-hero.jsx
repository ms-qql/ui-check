import React from "react";
import { Button, Slot } from "../lib/meridian-ui.jsx";

/*
 * meridian-hero — dunkler Hero mit zweizeiliger Display-Headline, zwei CTAs
 * (Primary mit irisierendem Glow) und perspektivisch gekipptem Produkt-Slot.
 * Section-Typ: hero.  Bild-Slots: hero-visual.
 * Props: { data } — Felder: title (string[]), body, ctas, imageSlot.
 */
export default function MeridianHero({ data = {} }) {
  const { id = "hero", title = [], body, ctas = [], imageSlot = "hero-visual" } = data;
  return (
    <section id={id} className="relative overflow-hidden bg-ink pt-36 text-paper">
      <div className="container-x">
        <h1 className="display max-w-4xl text-[clamp(2.75rem,7vw,5.5rem)]">
          {title.map((t, i) => <span key={i} className="block">{t}</span>)}
        </h1>
        <p className="mt-8 max-w-xl text-lg leading-relaxed text-muted">{body}</p>
        <div className="mt-10 flex flex-wrap items-center gap-6">
          {ctas.map((c) => (
            <Button key={c.label} size="lg" variant={c.variant} glow={c.glow}>{c.label}</Button>
          ))}
        </div>
      </div>

      {/* Perspektivisch gekipptes Produkt-Fenster (Slot) */}
      <div className="container-x mt-20" style={{ perspective: "2000px" }}>
        <div style={{ transform: "rotateX(32deg) rotateZ(-8deg) scale(1.05)", transformOrigin: "center top" }} className="mx-auto max-w-6xl">
          <Slot id={imageSlot} className="aspect-[16/9] w-full rounded-t-xl border border-paper/10 shadow-2xl" src={data.image} />
        </div>
      </div>
    </section>
  );
}
