import React from "react";
import { Slot, SpecCard } from "../lib/meridian-ui.jsx";

/*
 * meridian-glance — „at a glance": zweifarbige Headline + Spec-Karte,
 * darunter Bild-Slot (Registration-Marks) und A–F-Feature-Liste.
 * Section-Typ: feature-list.  Bild-Slots: glance-visual.
 * Props: { data } — Felder: kicker, title, spec {title,tag,rows}, rows[], footL, footR, imageSlot, imageLabel.
 */
export default function MeridianGlance({ data = {} }) {
  const { id = "glance", kicker, title, spec = {}, rows = [], footL, footR, imageSlot = "glance-visual", imageLabel } = data;
  return (
    <section id={id} className="section-padding">
      <div className="container-x">
        <div className="flex flex-col justify-between gap-8 md:flex-row md:items-start">
          <h2 className="display text-[clamp(2.25rem,5vw,4rem)]">
            <span className="text-paper">{kicker}</span> <span className="text-muted">{title}</span>
          </h2>
          <SpecCard head={{ title: spec.title, tag: spec.tag }} rows={spec.rows || []} className="w-full max-w-xs shrink-0" />
        </div>

        <div className="mt-16 grid gap-10 lg:grid-cols-2">
          {/* Bild-Slot mit Registration-Marks */}
          <div>
            <div className="relative aspect-square">
              <span aria-hidden className="absolute -left-1 -top-1 h-4 w-4 border-l border-t border-paper/40" />
              <span aria-hidden className="absolute -right-1 -top-1 h-4 w-4 border-r border-t border-paper/40" />
              <span aria-hidden className="absolute -bottom-1 -left-1 h-4 w-4 border-b border-l border-paper/40" />
              <span aria-hidden className="absolute -bottom-1 -right-1 h-4 w-4 border-b border-r border-paper/40" />
              <Slot id={imageSlot} className="h-full w-full ring-1 ring-paper/15">
                {imageLabel && <span className="mono-label absolute inset-0 grid place-items-center text-paper/70">{imageLabel}</span>}
              </Slot>
            </div>
            <div className="mono-label mt-6 flex justify-between text-paper/40">
              <span>{footL}</span><span>{footR}</span>
            </div>
          </div>

          {/* A–F Zeilen */}
          <div>
            {rows.map((r) => (
              <div key={r.key} className="grid grid-cols-[2.5rem_1fr] gap-4 border-t border-paper/12 py-6 first:border-t-0 sm:grid-cols-[2.5rem_8rem_1fr]">
                <div className="font-display text-2xl font-medium text-paper/80">{r.key}.</div>
                <div className="mono-label pt-1.5 text-paper/40">{r.label}</div>
                <div className="col-span-2 sm:col-span-1">
                  <div className="text-lg font-medium text-paper">{r.title}</div>
                  <div className="mt-1 text-sm leading-relaxed text-muted">{r.sub}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
