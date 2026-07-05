import React from "react";
import { about } from "../content.js";
import { Eyebrow, Button, TextLink } from "../lib/ui.jsx";

function Stars({ n = 5 }) {
  return (
    <span className="text-accent">
      {"★★★★★".slice(0, n)}
    </span>
  );
}

export default function About() {
  return (
    <section className="section-padding">
      <div className="container-x grid gap-x-8 gap-y-14 lg:grid-cols-12">
        <div className="lg:col-span-3"><Eyebrow>About Us</Eyebrow></div>
        <div className="lg:col-span-9">
          <h2 className="display max-w-3xl text-[clamp(2rem,4.6vw,3.5rem)]">{about.title}</h2>
          <p className="mt-7 max-w-2xl text-[1.05rem] leading-relaxed text-muted">{about.body}</p>
          <TextLink href="#" className="mt-7">{about.cta}</TextLink>
        </div>

        {/* Bild-Karte */}
        <div className="lg:col-span-4">
          <div className="relative overflow-hidden rounded-2xl bg-neutral-950">
            <img src={about.image} alt="" className="aspect-[4/5] w-full object-cover opacity-90" />
            <div className="absolute inset-0 bg-gradient-to-t from-neutral-950 via-neutral-950/20 to-transparent" />
            <div className="absolute inset-x-0 bottom-0 p-6 text-white">
              <div className="text-lg font-medium">{about.imageTitle}</div>
              <div className="mt-1 text-sm text-white/70">{about.imageSub}</div>
              <Button variant="invert" className="mt-5 w-full">{about.imageCta}</Button>
            </div>
          </div>
        </div>

        {/* Metriken + Rating */}
        <div className="flex flex-col justify-end lg:col-span-8">
          <div className="grid grid-cols-2 gap-x-8 gap-y-10 sm:grid-cols-4">
            {about.metrics.map((m) => (
              <div key={m.value}>
                <div className="text-4xl font-medium tracking-tight md:text-5xl">{m.value}</div>
                <div className="mt-3 text-sm text-ink">{m.label}</div>
                <div className="text-sm text-muted">{m.sub}</div>
              </div>
            ))}
          </div>
          <div className="mt-10 flex flex-wrap items-center gap-x-8 gap-y-4 border-t border-line pt-6">
            <div className="flex items-center gap-2 text-sm">
              <span className="font-medium">{about.rating}</span> <Stars />
            </div>
            <div className="flex flex-wrap items-center gap-x-7 gap-y-3 opacity-80">
              {about.reviewLogos.map((l) => (
                <img key={l.alt} src={l.src} alt={l.alt} className={`${l.h} w-auto`} />
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
