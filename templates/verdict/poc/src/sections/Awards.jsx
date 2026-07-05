import React from "react";
import { awards } from "../content.js";
import { Eyebrow } from "../lib/ui.jsx";
import { cn } from "../lib/cn.js";

export default function Awards() {
  return (
    <section className="section-padding overflow-hidden">
      <div className="container-x">
        <div className="grid gap-x-8 gap-y-6 lg:grid-cols-12">
          <div className="lg:col-span-3"><Eyebrow>Our Awards</Eyebrow></div>
          <div className="lg:col-span-9">
            <h2 className="display max-w-2xl text-[clamp(2rem,4.6vw,3.5rem)]">{awards.title}</h2>
            <p className="mt-6 max-w-md text-[1.05rem] leading-relaxed text-muted">{awards.body}</p>
          </div>
        </div>

        <div className="mt-12 grid gap-8 lg:grid-cols-12">
          <div className="lg:col-span-3 lg:self-end">
            <div className="overflow-hidden rounded-2xl">
              <img src={awards.image} alt="" className="aspect-[4/5] w-full object-cover" />
            </div>
          </div>
          <ul className="lg:col-span-9">
            {awards.items.map((a, i) => (
              <li key={a.n}>
                <div className={cn(
                  "flex items-center gap-6 rounded-xl px-6 py-6",
                  i === 0 ? "bg-neutral-950 text-white" : "border-b border-line"
                )}>
                  <span className={cn("mono-label text-lg", i === 0 ? "text-white/50" : "text-accent")}>{a.n}.</span>
                  <span className="flex-1 text-lg font-medium md:text-xl">{a.name}</span>
                  <span className={cn("text-lg", i === 0 ? "text-white/60" : "text-muted")}>{a.year}</span>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
