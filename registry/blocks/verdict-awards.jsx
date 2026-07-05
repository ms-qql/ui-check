import React from "react";
import { Eyebrow, Slot } from "../lib/ui.jsx";
import { cn } from "../lib/cn.js";

/*
 * verdict-awards — Foto-Kachel plus Auszeichnungs-Liste (erster Eintrag invertiert).
 * Section-Typ: awards.  Bild-Slots: awards-visual.
 * Props: { data } aus content.json (Sektion mit type "awards").
 */
export default function VerdictAwards({ data = {} }) {
  const { id = "awards", eyebrow, title, body, items = [] } = data;
  return (
    <section id={id} className="section-padding overflow-hidden">
      <div className="container-x">
        <div className="grid gap-x-8 gap-y-6 lg:grid-cols-12">
          <div className="lg:col-span-3"><Eyebrow>{eyebrow}</Eyebrow></div>
          <div className="lg:col-span-9">
            <h2 className="display max-w-2xl text-[clamp(2rem,4.6vw,3.5rem)]">{title}</h2>
            <p className="mt-6 max-w-md text-[1.05rem] leading-relaxed text-muted">{body}</p>
          </div>
        </div>

        <div className="mt-12 grid gap-8 lg:grid-cols-12">
          <div className="lg:col-span-3 lg:self-end">
            <Slot id="awards-visual" className="aspect-[4/5] w-full rounded-2xl" imgClass="object-cover" />
          </div>
          <ul className="lg:col-span-9">
            {items.map((a, i) => (
              <li key={a.n}>
                <div className={cn(
                  "flex items-center gap-6 rounded-xl px-6 py-6",
                  i === 0 ? "bg-ink text-paper" : "border-b border-line"
                )}>
                  <span className={cn("mono-label text-lg", i === 0 ? "text-paper/50" : "text-accent")}>{a.n}.</span>
                  <span className="flex-1 text-lg font-medium md:text-xl">{a.name}</span>
                  <span className={cn("text-lg", i === 0 ? "text-paper/60" : "text-muted")}>{a.year}</span>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
