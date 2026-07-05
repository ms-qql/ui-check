import React from "react";

function WatchMock({ d }) {
  return (
    <div className="rounded-2xl border border-paper/12 bg-ink-soft/50 p-6">
      <div className="mx-auto max-w-[300px] rounded-[2.5rem] bg-ink p-3 ring-1 ring-paper/15">
        <div className="rounded-[2rem] bg-black px-5 py-6 ring-1 ring-paper/10">
          <div className="mono-label flex items-center justify-between text-paper/60">
            <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-accent" />{d.time}</span>
            <span>{d.battery}</span>
          </div>
          <div className="mt-6 text-center">
            <div className="mono-label text-paper/40">{d.app}</div>
            <div className="mt-2 inline-block rounded-full bg-accent px-3 py-0.5 text-[0.7rem] font-semibold text-paper">{d.badge}</div>
            <div className="mt-4 text-2xl font-medium text-paper">{d.metric}</div>
            <div className="mono-label mt-1 text-paper/40">{d.scope}</div>
            <div className="mt-6 flex items-end justify-center gap-1">
              <span className="text-5xl font-light leading-none text-paper" style={{ fontFamily: "var(--font-display)" }}>{d.value}</span>
              <span className="mono-label pb-1 text-paper/40">{d.max}</span>
            </div>
            <div className="mono-label mt-1 text-paper/40">{d.meterLabel}</div>
            <div className="mt-2 h-1 overflow-hidden rounded-full bg-paper/10">
              <div className="h-full rounded-full bg-accent" style={{ width: `${d.burn * 100}%` }} />
            </div>
          </div>
          <div className="mt-6 space-y-2">
            {d.actions.map((a) => (
              <div key={a.label} className={`mono-label rounded-full py-3 text-center ${a.primary ? "bg-paper text-ink" : "bg-paper/10 text-paper/80"}`}>{a.label}</div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

export default function Flow({ data = {} }) {
  const { kicker, title = [], steps = [], device, nowShowing, step } = data;
  return (
    <section id="flow" className="section-padding">
      <div className="container-x">
        <div className="mono-label text-paper/40">{kicker}</div>
        <h2 className="display mt-6 max-w-3xl text-[clamp(2.5rem,5.5vw,4.5rem)]">
          <span className="text-paper">{title[0]} </span><span className="text-muted">{title[1]}</span>
        </h2>

        <div className="mt-14 grid gap-12 lg:grid-cols-2">
          <div>
            {steps.map((s, i) => (
              <div key={s.num} className="border-t border-paper/12 py-8 first:border-t-0">
                <div className="mono-label text-paper/40">{s.num} · {s.tag}</div>
                <h3 className={`mt-3 text-2xl font-medium md:text-3xl ${i === 0 ? "text-paper" : "text-muted"}`} style={{ fontFamily: "var(--font-display)", borderLeft: i === 0 ? "2px solid var(--color-paper)" : "none", paddingLeft: i === 0 ? "1rem" : 0, marginLeft: i === 0 ? "-1rem" : 0 }}>
                  {s.title}
                </h3>
                <p className="mt-3 max-w-md text-sm leading-relaxed text-muted">{s.body}</p>
              </div>
            ))}
          </div>

          <div className="lg:sticky lg:top-24 lg:self-start">
            <WatchMock d={device} />
            <div className="mono-label mt-4 flex justify-between text-paper/40">
              <span>Now showing · <span className="text-paper/70">{nowShowing}</span></span>
              <span>{step}</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
