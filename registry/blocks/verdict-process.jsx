import React, { useState } from "react";
import { Eyebrow, Slot } from "../lib/ui.jsx";
import { cn } from "../lib/cn.js";

/*
 * verdict-process — dunkler Foto-Crossfade mit interaktivem Step-Tracker.
 * Section-Typ: process.  Bild-Slots: process-1 … process-5.
 * Props: { data } aus content.json (Sektion mit type "process").
 */
export default function VerdictProcess({ data = {} }) {
  const { id = "process", eyebrow, title, body, steps = [] } = data;
  const [active, setActive] = useState(0);
  const step = steps[active] || {};
  return (
    <section id={id} className="section-padding">
      <div className="container-x">
        <div className="grid gap-x-8 gap-y-6 lg:grid-cols-12">
          <div className="lg:col-span-3"><Eyebrow>{eyebrow}</Eyebrow></div>
          <div className="lg:col-span-9">
            <h2 className="display max-w-2xl text-[clamp(2rem,4.6vw,3.5rem)]">{title}</h2>
            <p className="mt-6 max-w-xl text-[1.05rem] leading-relaxed text-muted">{body}</p>
          </div>
        </div>

        <div className="mt-12 overflow-hidden rounded-3xl bg-ink text-paper">
          <div className="relative min-h-[640px]">
            {steps.map((s, i) => (
              <Slot
                key={i}
                id={`process-${s.n}`}
                dark
                className={cn("absolute inset-0 h-full w-full transition-opacity duration-700", i === active ? "opacity-70" : "opacity-0")}
                imgClass="object-cover"
              />
            ))}
            <div className="absolute inset-0 bg-gradient-to-r from-ink/90 via-ink/40 to-transparent" />
            <div className="absolute inset-x-0 bottom-0 p-8 md:p-12">
              <div className="mono-label flex items-center gap-3 text-paper/70">
                <span className="h-px w-8 bg-paper/50" /> Step {step.n} of {steps.length}
              </div>
              <h3 className="display mt-4 text-[clamp(2.5rem,6vw,4.5rem)]">{step.name}</h3>
              <p className="mt-5 max-w-md text-[1.05rem] leading-relaxed text-paper/80">{step.desc}</p>
            </div>
          </div>

          {/* Step-Tracker */}
          <div className="grid grid-cols-2 border-t border-paper/10 md:grid-cols-5">
            {steps.map((s, i) => (
              <button
                key={i}
                onClick={() => setActive(i)}
                onMouseEnter={() => setActive(i)}
                className={cn(
                  "border-paper/10 px-6 py-6 text-left transition-colors [&:not(:last-child)]:border-r",
                  i === active ? "bg-paper/10" : "hover:bg-paper/5"
                )}
              >
                <div className="mono-label text-paper/50">Step {s.n}</div>
                <div className={cn("mt-1.5 font-medium", i === active ? "text-paper" : "text-paper/70")}>{s.name}</div>
              </button>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
