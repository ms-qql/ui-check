import React from "react";
import { Button, Barcode } from "../lib/ui.jsx";
import { cn } from "../lib/cn.js";

function Ticket({ p }) {
  const light = p.featured;
  const dash = light ? "border-ink/20" : "border-paper/20";
  const dim = light ? "text-ink/50" : "text-paper/45";
  const strong = light ? "text-ink" : "text-paper";
  return (
    <div className={cn("relative rounded-xl p-7 font-mono text-sm", light ? "bg-paper text-ink shadow-2xl lg:-my-6 lg:scale-[1.04]" : "border border-paper/12 bg-ink-soft/40 text-paper")}>
      {p.stamp && (
        <span className="absolute -right-2 top-8 -rotate-6 rounded border border-ink/30 px-3 py-1 text-[0.6rem] uppercase tracking-widest text-ink/70">{p.stamp}</span>
      )}
      {/* Perforationskerben */}
      <span aria-hidden className="absolute -left-2.5 top-[58%] h-5 w-5 rounded-full bg-ink" />
      <span aria-hidden className="absolute -right-2.5 top-[58%] h-5 w-5 rounded-full bg-ink" />

      <div className={cn("flex items-center justify-between text-xs uppercase tracking-widest", dim)}>
        <span>Meridian · {p.name}</span><span>{p.code}</span>
      </div>
      <div className={cn("my-4 border-t border-dashed", dash)} />

      <h3 className={cn("text-xl leading-snug", strong)} style={{ fontFamily: "var(--font-display)" }}>{p.blurb}</h3>

      <div className={cn("mt-6 text-[0.65rem] uppercase tracking-widest", dim)}>Includes</div>
      <ul className="mt-3 space-y-2">
        {p.includes.map((it) => (
          <li key={it} className="flex items-baseline gap-2">
            <span className={strong}>·</span>
            <span className={cn("flex-1", light ? "text-ink/80" : "text-paper/80")}>{it}</span>
            <span className={cn("shrink-0", dim)}>incl.</span>
          </li>
        ))}
      </ul>

      <div className={cn("my-5 border-t border-dashed", dash)} />
      <dl className="space-y-1.5">
        {p.lines.map(([k, v]) => (
          <div key={k} className="flex justify-between"><dt className={dim}>{k}</dt><dd className={cn(light ? "text-ink/80" : "text-paper/80")}>{v}</dd></div>
        ))}
      </dl>

      <div className={cn("my-5 border-t border-dashed", dash)} />
      <div className="flex items-baseline justify-between">
        <span className={cn("text-xs uppercase tracking-widest", dim)}>Total due</span>
        <span className="flex items-baseline gap-1">
          <span className={cn("text-3xl", strong)} style={{ fontFamily: "var(--font-display)" }}>{p.total}</span>
          <span className={dim}>{p.per}</span>
        </span>
      </div>

      <div className={cn("my-5 border-t border-dashed", dash)} />
      <div className={cn("flex justify-between text-[0.6rem] uppercase tracking-widest", dim)}>
        <span>{p.auth}</span><span>Holder · your team</span>
      </div>
      <div className="mt-4 flex justify-center"><Barcode seed={p.code} dark={light} /></div>

      <div className="mt-6 text-center">
        {light
          ? <Button variant="primary" glow>{p.cta}</Button>
          : <span className="text-sm uppercase tracking-widest">{p.cta}</span>}
      </div>
    </div>
  );
}

export default function Pricing({ data = {} }) {
  const { bar, title = [], foot, plans = [] } = data;
  return (
    <section id="pricing" className="section-padding">
      <div className="container-x">
        <div className="text-center">
          <div className="mono-label text-paper/40">{bar}</div>
          <h2 className="display mx-auto mt-6 max-w-3xl text-[clamp(2.25rem,5vw,3.75rem)]">
            <span className="text-paper">{title[0]} </span><span className="text-muted">{title[1]}</span>
          </h2>
        </div>

        <div className="mt-20 grid gap-6 md:grid-cols-3 md:items-center">
          {plans.map((p) => <Ticket key={p.name} p={p} />)}
        </div>

        <p className="mono-label mt-16 text-center text-paper/35">{foot}</p>
      </div>
    </section>
  );
}
