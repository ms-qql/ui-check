import React from "react";
import { Eyebrow, Button, TextLink, Slot } from "../lib/ui.jsx";

/*
 * verdict-about — Über-uns-Block: Text + Bild-Karte + Kennzahlen + Rating.
 * Section-Typ: about.  Bild-Slots: about-visual.
 * Props: { data } aus content.json (Sektion mit type "about").
 */
function Stars({ n = 5 }) {
  return <span className="text-accent">{"★★★★★".slice(0, n)}</span>;
}

export default function VerdictAbout({ data = {} }) {
  const {
    id = "about",
    eyebrow = "About Us",
    title,
    body,
    cta,
    imageTitle,
    imageSub,
    imageCta,
    metrics = [],
    rating,
    reviewLogos = [],
  } = data;

  return (
    <section id={id} className="section-padding">
      <div className="container-x grid gap-x-8 gap-y-14 lg:grid-cols-12">
        <div className="lg:col-span-3"><Eyebrow>{eyebrow}</Eyebrow></div>
        <div className="lg:col-span-9">
          <h2 className="display max-w-3xl text-[clamp(2rem,4.6vw,3.5rem)]">{title}</h2>
          <p className="mt-7 max-w-2xl text-[1.05rem] leading-relaxed text-muted">{body}</p>
          <TextLink href="#" className="mt-7">{cta}</TextLink>
        </div>

        {/* Bild-Karte */}
        <div className="lg:col-span-4">
          <Slot id="about-visual" dark className="aspect-[4/5] rounded-2xl" imgClass="opacity-90">
            <div className="absolute inset-0 bg-gradient-to-t from-ink via-ink/20 to-transparent" />
            <div className="absolute inset-x-0 bottom-0 p-6 text-paper">
              <div className="text-lg font-medium">{imageTitle}</div>
              <div className="mt-1 text-sm text-paper/70">{imageSub}</div>
              <Button variant="invert" className="mt-5 w-full">{imageCta}</Button>
            </div>
          </Slot>
        </div>

        {/* Metriken + Rating */}
        <div className="flex flex-col justify-end lg:col-span-8">
          <div className="grid grid-cols-2 gap-x-8 gap-y-10 sm:grid-cols-4">
            {metrics.map((m) => (
              <div key={m.value}>
                <div className="text-4xl font-medium tracking-tight md:text-5xl">{m.value}</div>
                <div className="mt-3 text-sm text-ink">{m.label}</div>
                <div className="text-sm text-muted">{m.sub}</div>
              </div>
            ))}
          </div>
          <div className="mt-10 flex flex-wrap items-center gap-x-8 gap-y-4 border-t border-line pt-6">
            <div className="flex items-center gap-2 text-sm">
              <span className="font-medium">{rating}</span> <Stars />
            </div>
            <div className="flex flex-wrap items-center gap-x-7 gap-y-3 opacity-80">
              {reviewLogos.map((l) => (
                <span key={l.alt} className="mono-label text-muted">{l.alt}</span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
