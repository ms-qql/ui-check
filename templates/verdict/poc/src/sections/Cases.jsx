import React from "react";
import { cases } from "../content.js";
import { Eyebrow, Button } from "../lib/ui.jsx";

function CaseCard({ c, i }) {
  const imageLeft = i % 2 === 0;
  return (
    <article className="overflow-hidden rounded-3xl border border-line bg-paper shadow-[0_20px_60px_-25px_rgba(0,0,0,0.25)]">
      <div className="grid md:grid-cols-2">
        <div className={`relative min-h-[280px] md:min-h-[520px] ${imageLeft ? "md:order-1" : "md:order-2"}`}>
          <img src={c.image} alt="" className="absolute inset-0 h-full w-full object-cover" />
        </div>
        <div className={`flex flex-col p-8 md:p-12 ${imageLeft ? "md:order-2" : "md:order-1"}`}>
          <div className="flex items-center gap-3 mono-label text-muted">
            <span>Case · {c.year}</span>
            <span className="h-px w-6 bg-accent" />
            <span className="text-ink">{c.num}</span>
          </div>
          <div className="mt-6 flex flex-wrap gap-x-3 gap-y-1 mono-label text-muted">
            {c.tags.map((t, k) => (
              <span key={t} className="flex items-center gap-3">
                {k > 0 && <span className="text-line">/</span>}{t}
              </span>
            ))}
          </div>
          <h3 className="mt-5 max-w-md text-2xl font-medium leading-snug md:text-[1.9rem]">{c.title}</h3>
          <p className="mt-auto pt-8 text-[1.05rem] text-ink">{c.result}</p>
          <div className="mt-5 mono-label text-muted">{c.court} · {c.year}</div>
          <Button className="mt-7 self-start">Read the full case study ↗</Button>
        </div>
      </div>
    </article>
  );
}

export default function Cases() {
  return (
    <section className="section-padding">
      <div className="container-x">
        <div className="grid gap-x-8 gap-y-6 lg:grid-cols-12">
          <div className="lg:col-span-3"><Eyebrow>Featured Case Studies</Eyebrow></div>
          <div className="lg:col-span-9">
            <h2 className="display max-w-xl text-[clamp(2rem,4.6vw,3.5rem)]">{cases.title}</h2>
            <p className="mt-6 max-w-lg text-[1.05rem] leading-relaxed text-muted">{cases.body}</p>
          </div>
        </div>

        {/* Sticky-Stack der Fall-Karten */}
        <div className="mt-14">
          {cases.items.map((c, i) => (
            <div key={c.num} className="sticky pb-8" style={{ top: `${96 + i * 18}px` }}>
              <CaseCard c={c} i={i} />
            </div>
          ))}
        </div>

        <div className="mt-4 flex justify-center">
          <Button variant="soft" size="lg">{cases.cta} →</Button>
        </div>
      </div>
    </section>
  );
}
