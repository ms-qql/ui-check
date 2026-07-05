import React from "react";
import { Eyebrow, Slot } from "../lib/ui.jsx";
import { cn } from "../lib/cn.js";

function ArrowBadge() {
  return (
    <span className="absolute right-3 top-3 grid h-7 w-7 place-items-center rounded-full bg-paper/80 text-xs text-ink shadow-sm backdrop-blur">↗</span>
  );
}

function Cell({ c, i }) {
  const base = "relative aspect-square overflow-hidden rounded-2xl";
  if (c.type === "empty") return <div className="aspect-square" />;
  if (c.type === "photo")
    return (
      <Slot id={`testimonial-${i}`} className={cn(base, "bg-surface")} imgClass="grayscale">
        <ArrowBadge />
        {c.caption && <span className="mono-label absolute bottom-3 left-3 text-paper/90">— {c.caption}</span>}
      </Slot>
    );
  if (c.type === "quote")
    return (
      <div className={cn(base, c.dark ? "bg-ink text-paper" : "border border-line bg-paper", "flex flex-col p-6")}>
        <span className={cn("font-serif text-3xl leading-none", c.dark ? "text-paper/40" : "text-ink/30")}>“</span>
        <ArrowBadge />
        <p className="mt-auto text-lg font-medium">“{c.quote}”</p>
        <span className={cn("mono-label mt-4", c.dark ? "text-accent" : "text-muted")}>— {c.tag}</span>
      </div>
    );
  // stat
  return (
    <div className={cn(base, c.accent ? "bg-sand text-ink" : c.dark ? "bg-ink text-paper" : "border border-line bg-paper", "flex flex-col p-6")}>
      <span className={cn("mono-label", c.dark ? "text-paper/50" : c.accent ? "text-ink/60" : "text-muted")}>{c.label}</span>
      <div className="mt-auto text-4xl font-medium tracking-tight md:text-5xl">{c.value}</div>
      <span className={cn("mono-label mt-3", c.dark ? "text-paper/50" : c.accent ? "text-ink/60" : "text-muted")}>— {c.meta}</span>
    </div>
  );
}

/*
 * verdict-testimonials — Bento-Grid aus Foto-, Zitat-, Stat- und Leer-Zellen.
 * Section-Typ: testimonials.  Bild-Slots: testimonial-<Zellindex> (nur type "photo").
 * Props: { data } aus content.json (Sektion mit type "testimonials").
 */
export default function VerdictTestimonials({ data = {} }) {
  const { id = "testimonials", eyebrow, title, body, cells = [] } = data;
  return (
    <section id={id} className="section-padding overflow-hidden">
      <div className="container-x">
        <div className="mb-14 text-center">
          <div className="mb-6 flex justify-start"><Eyebrow>{eyebrow}</Eyebrow></div>
          <h2 className="display mx-auto max-w-2xl text-[clamp(2rem,4.8vw,3.75rem)]">{title}</h2>
          <p className="mx-auto mt-6 max-w-xl text-[1.05rem] leading-relaxed text-muted">{body}</p>
        </div>

        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
          {cells.map((c, i) => <Cell key={i} c={c} i={i} />)}
        </div>
      </div>
    </section>
  );
}
