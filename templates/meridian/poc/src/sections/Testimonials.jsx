import React from "react";
import { DispatchBar, Slot } from "../lib/ui.jsx";

export default function Testimonials({ data = {} }) {
  const { barLeft, barCenter, barRight, title = [], items = [] } = data;
  return (
    <section id="testimonials" className="relative overflow-hidden py-4">
      <DispatchBar left={barLeft} center={barCenter} right={barRight} />

      <div className="container-x pt-14">
        <h2 className="display max-w-5xl text-[clamp(2.5rem,5.5vw,4.5rem)]">
          <span className="text-paper">{title[0]} </span><span className="text-muted">{title[1]}</span>
        </h2>
      </div>

      <div className="container-x mt-14 flex snap-x gap-6 overflow-x-auto pb-4">
        {items.map((it) => (
          <figure key={it.n} className="flex w-[min(28rem,85vw)] shrink-0 snap-start flex-col overflow-hidden rounded-xl border border-paper/10 bg-ink-soft/40">
            <div className="relative">
              <Slot id={it.slot} className="aspect-[4/5] w-full" />
              <span className="mono-label absolute left-4 top-4 flex items-center gap-1.5 rounded-full bg-ink/70 px-2.5 py-1 text-paper/70 backdrop-blur">
                <span className="h-1.5 w-1.5 rounded-full bg-paper/60" />{it.n}
              </span>
            </div>
            <div className="flex flex-1 flex-col p-7">
              <span className="text-3xl leading-none text-paper/30" style={{ fontFamily: "var(--font-display)" }}>&ldquo;</span>
              <blockquote className="mt-2 text-lg leading-relaxed text-paper">{it.quote}</blockquote>
              <div className="mono-label mt-6 border-t border-paper/10 pt-4 text-paper/60">
                {it.who} · {it.role} · {it.org}
              </div>
              <div className="mono-label mt-3 flex justify-between text-paper/35">
                <span>{it.filed}</span><span>{it.frame}</span>
              </div>
            </div>
          </figure>
        ))}
      </div>

      <div className="container-x flex items-center justify-between">
        <div className="flex gap-2">
          {items.map((_, i) => <span key={i} className={`h-0.5 w-8 ${i === 0 ? "bg-paper" : "bg-paper/25"}`} />)}
        </div>
        <div className="flex gap-2">
          {["‹", "›"].map((a) => (
            <button key={a} className="grid h-9 w-9 place-items-center rounded-full border border-paper/20 text-paper/60 transition-colors hover:bg-paper/10">{a}</button>
          ))}
        </div>
      </div>
    </section>
  );
}
