import React, { useState } from "react";
import { process } from "../content.js";
import { Eyebrow } from "../lib/ui.jsx";
import { cn } from "../lib/cn.js";

export default function Process() {
  const [active, setActive] = useState(0);
  const step = process.steps[active];
  return (
    <section className="section-padding">
      <div className="container-x">
        <div className="grid gap-x-8 gap-y-6 lg:grid-cols-12">
          <div className="lg:col-span-3"><Eyebrow>Our Process</Eyebrow></div>
          <div className="lg:col-span-9">
            <h2 className="display max-w-2xl text-[clamp(2rem,4.6vw,3.5rem)]">{process.title}</h2>
            <p className="mt-6 max-w-xl text-[1.05rem] leading-relaxed text-muted">{process.body}</p>
          </div>
        </div>

        <div className="mt-12 overflow-hidden rounded-3xl bg-neutral-950 text-white">
          <div className="relative min-h-[640px]">
            {process.steps.map((s, i) => (
              <img key={i} src={s.image} alt="" className={cn("absolute inset-0 h-full w-full object-cover transition-opacity duration-700", i === active ? "opacity-70" : "opacity-0")} />
            ))}
            <div className="absolute inset-0 bg-gradient-to-r from-neutral-950/90 via-neutral-950/40 to-transparent" />
            <div className="absolute inset-x-0 bottom-0 p-8 md:p-12">
              <div className="mono-label flex items-center gap-3 text-white/70">
                <span className="h-px w-8 bg-white/50" /> Step {step.n} of {process.steps.length}
              </div>
              <h3 className="display mt-4 text-[clamp(2.5rem,6vw,4.5rem)]">{step.name}</h3>
              <p className="mt-5 max-w-md text-[1.05rem] leading-relaxed text-white/80">{step.desc}</p>
            </div>
          </div>

          {/* Step-Tracker */}
          <div className="grid grid-cols-2 border-t border-white/10 md:grid-cols-5">
            {process.steps.map((s, i) => (
              <button
                key={i}
                onClick={() => setActive(i)}
                onMouseEnter={() => setActive(i)}
                className={cn(
                  "border-white/10 px-6 py-6 text-left transition-colors [&:not(:last-child)]:border-r",
                  i === active ? "bg-white/10" : "hover:bg-white/5"
                )}
              >
                <div className="mono-label text-white/50">Step {s.n}</div>
                <div className={cn("mt-1.5 font-medium", i === active ? "text-white" : "text-white/70")}>{s.name}</div>
              </button>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
