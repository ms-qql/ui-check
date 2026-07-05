import React from "react";
import { team } from "../content.js";
import { Eyebrow, Button } from "../lib/ui.jsx";
import { cn } from "../lib/cn.js";

const offset = ["", "lg:mt-14", "lg:mt-14", "", "", "lg:mt-14"];

export default function Team() {
  return (
    <section className="section-padding overflow-hidden">
      <div className="container-x">
        <div className="relative mb-16 text-center">
          <div className="mb-6 flex justify-start"><Eyebrow>Our Team</Eyebrow></div>
          <h2 className="display mx-auto max-w-3xl text-[clamp(2rem,4.8vw,3.75rem)]">{team.title}</h2>
          <p className="mx-auto mt-6 max-w-xl text-[1.05rem] leading-relaxed text-muted">{team.body}</p>
        </div>

        <div className="grid grid-cols-2 gap-6 lg:grid-cols-3">
          {team.members.map((m, i) => (
            <figure key={m.name} className={cn("group relative overflow-hidden rounded-2xl bg-neutral-950", offset[i])}>
              <img src={m.image} alt={m.name} className="aspect-[4/5] w-full object-cover transition-transform duration-500 group-hover:scale-[1.03]" />
              <div className="absolute inset-0 bg-gradient-to-t from-neutral-950 via-neutral-950/10 to-transparent" />
              <figcaption className="absolute inset-x-0 bottom-0 p-6 text-white">
                <div className="text-xl font-medium">{m.name}</div>
                <div className="mono-label mt-1 text-white/60">{m.role}</div>
              </figcaption>
            </figure>
          ))}
        </div>

        <div className="mt-14 flex justify-center">
          <Button variant="soft" size="lg">{team.cta} →</Button>
        </div>
      </div>
    </section>
  );
}
