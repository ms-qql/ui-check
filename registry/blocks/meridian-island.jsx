import React from "react";

/*
 * meridian-island — großes „Blueprint"-Panel (metallischer Rahmen) mit
 * Phone-/Dynamic-Island-Mockup links und zyklischer Live-Aktivitäts-Liste rechts.
 * Section-Typ: showcase.  Keine Bild-Slots (Device ist code-gerendertes UI).
 * Props: { data } — Felder: kicker, title[], nowCycling, subtitle[], device{}, activities[], body.
 */
function PhoneMock({ d = {} }) {
  return (
    <div className="mx-auto w-[280px] rounded-[3rem] bg-ink p-3 shadow-2xl ring-1 ring-paper/20">
      <div className="relative overflow-hidden rounded-[2.4rem] bg-surface">
        <div className="absolute left-1/2 top-3 z-10 flex -translate-x-1/2 items-center gap-2 rounded-full bg-ink px-3 py-1.5">
          <span className="h-1.5 w-1.5 rounded-full bg-accent" />
          <span className="mono-label text-[0.55rem] text-paper/80">{d.pill}</span>
        </div>
        <div className="px-6 pb-6 pt-16 text-center text-ink">
          <div className="text-sm font-medium">{d.date}</div>
          <div className="font-display text-7xl font-light tracking-tight">{d.time}</div>
        </div>
        <div className="mx-3 mb-3 rounded-2xl bg-paper/80 p-3 backdrop-blur">
          <div className="mono-label flex justify-between text-ink/50"><span>● Meridian</span><span>now</span></div>
          <p className="mt-1.5 text-left text-xs text-ink/80">{d.note}</p>
        </div>
      </div>
    </div>
  );
}

export default function MeridianIsland({ data = {} }) {
  const { id = "island", kicker, title = [], nowCycling, subtitle = [], device = {}, activities = [], body } = data;
  return (
    <section id={id} className="section-padding">
      <div className="container-x">
        <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-paper/25 via-paper/5 to-paper/20 p-1">
          <div className="rounded-[1.35rem] bg-ink px-6 py-16 md:px-14">
            <div className="text-center">
              <div className="mono-label flex items-center justify-center gap-2 text-paper/40">
                <span className="h-1.5 w-1.5 rounded-full bg-paper/50" />{kicker}
              </div>
              <h2 className="display mx-auto mt-6 max-w-2xl text-[clamp(2.25rem,5vw,3.75rem)]">
                <span className="text-paper">{title[0]} </span><span className="text-muted">{title[1]}</span>
              </h2>
            </div>

            <div className="mt-16 grid items-center gap-14 lg:grid-cols-2">
              <PhoneMock d={device} />

              <div>
                <div className="mono-label text-paper/40">{nowCycling}</div>
                <h3 className="display mt-3 text-3xl md:text-4xl">
                  <span className="text-muted">{subtitle[0]}</span>
                  <span className="text-paper">{subtitle[1]}</span>
                  <span className="text-muted">{subtitle[2]}</span>
                </h3>
                <ul className="mt-8 space-y-1">
                  {activities.map((a) => (
                    <li key={a.num} className={`flex items-center gap-4 rounded-xl px-4 py-3 ${a.live ? "bg-ink-soft ring-1 ring-paper/10" : ""}`}>
                      <span className="h-1.5 w-1.5 rounded-full bg-paper/40" />
                      <span className="mono-label text-paper/35">{a.num}</span>
                      <span className="text-lg font-medium text-paper">{a.name}</span>
                      <span className="mono-label ml-auto text-paper/40">{a.meta}</span>
                      {a.live && <span className="mono-label rounded-full bg-paper px-2 py-0.5 text-[0.6rem] text-ink">LIVE</span>}
                    </li>
                  ))}
                </ul>
                <p className="mt-8 border-t border-paper/10 pt-6 text-sm leading-relaxed text-muted">{body}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
