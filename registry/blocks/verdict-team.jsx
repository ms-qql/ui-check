import React from "react";
import { Eyebrow, Button, Slot } from "../lib/ui.jsx";
import { cn } from "../lib/cn.js";

const offset = ["", "lg:mt-14", "lg:mt-14", "", "", "lg:mt-14"];

/*
 * verdict-team — versetztes Foto-Raster der Team-Mitglieder mit Hover-Zoom.
 * Section-Typ: team.  Bild-Slots: team-1 … team-6.
 * Props: { data } aus content.json (Sektion mit type "team").
 */
export default function VerdictTeam({ data = {} }) {
  const { id = "team", eyebrow, title, body, cta, members = [] } = data;
  return (
    <section id={id} className="section-padding overflow-hidden">
      <div className="container-x">
        <div className="relative mb-16 text-center">
          <div className="mb-6 flex justify-start"><Eyebrow>{eyebrow}</Eyebrow></div>
          <h2 className="display mx-auto max-w-3xl text-[clamp(2rem,4.8vw,3.75rem)]">{title}</h2>
          <p className="mx-auto mt-6 max-w-xl text-[1.05rem] leading-relaxed text-muted">{body}</p>
        </div>

        <div className="grid grid-cols-2 gap-6 lg:grid-cols-3">
          {members.map((m, i) => (
            <figure key={m.name} className={cn("group relative overflow-hidden rounded-2xl bg-ink", offset[i])}>
              <Slot
                id={`team-${i + 1}`}
                dark
                className="aspect-[4/5] w-full"
                imgClass="object-cover transition-transform duration-500 group-hover:scale-[1.03]"
              >
                <div className="absolute inset-0 bg-gradient-to-t from-ink via-ink/10 to-transparent" />
                <figcaption className="absolute inset-x-0 bottom-0 p-6 text-paper">
                  <div className="text-xl font-medium">{m.name}</div>
                  <div className="mono-label mt-1 text-paper/60">{m.role}</div>
                </figcaption>
              </Slot>
            </figure>
          ))}
        </div>

        <div className="mt-14 flex justify-center">
          <Button variant="soft" size="lg">{cta} →</Button>
        </div>
      </div>
    </section>
  );
}
