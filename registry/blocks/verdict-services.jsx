import React, { useState } from "react";
import { Eyebrow, Slot } from "../lib/ui.jsx";

/*
 * verdict-services — interaktiver Panel-Strip (Hover/Focus expandiert ein Panel).
 * Section-Typ: services.  Bild-Slots: service-01 … service-05.
 * Props: { data } aus content.json (Sektion mit type "services").
 */
export default function VerdictServices({ data = {} }) {
  const { id = "services", eyebrow = "Our Services", title, body, hint, items = [] } = data;
  const [active, setActive] = useState(0);

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

        {/* Interaktiver Panel-Strip */}
        <div className="mt-12 flex h-[560px] gap-1.5 overflow-hidden rounded-2xl">
          {items.map((it, i) => {
            const isActive = i === active;
            return (
              <button
                key={it.num}
                onMouseEnter={() => setActive(i)}
                onFocus={() => setActive(i)}
                className="group relative overflow-hidden bg-ink text-left text-paper transition-all duration-500 ease-out"
                style={{ flexGrow: isActive ? 6 : 1, flexBasis: 0 }}
              >
                {/* Bild nur im aktiven Panel */}
                <Slot
                  id={`service-${it.vol}`}
                  dark
                  className={`absolute inset-0 transition-opacity duration-500 ${isActive ? "opacity-60" : "opacity-0"}`}
                />
                <div className="absolute inset-0 bg-gradient-to-t from-ink via-ink/30 to-transparent" />

                {/* Collapsed: Roman + vertikaler Text */}
                <div className={`absolute inset-0 flex flex-col items-center justify-between py-8 transition-opacity duration-300 ${isActive ? "opacity-0" : "opacity-100"}`}>
                  <span className="mono-label text-accent/90">{it.num}</span>
                  <span className="mono-label whitespace-nowrap text-paper/80 [writing-mode:vertical-rl] rotate-180">{it.name}</span>
                  <span className="mono-label text-paper/40">Verdict · {it.vol}</span>
                </div>

                {/* Expanded: Titel + Beschreibung unten */}
                <div className={`absolute inset-x-0 bottom-0 p-7 transition-opacity duration-500 ${isActive ? "opacity-100 delay-100" : "opacity-0"}`}>
                  <div className="mono-label text-paper/60">Selected {it.num}</div>
                  <h3 className="mt-2 text-2xl font-medium md:text-3xl">{it.name}</h3>
                  <p className="mt-3 max-w-md text-sm leading-relaxed text-paper/75">{it.desc}</p>
                </div>
              </button>
            );
          })}
        </div>
        <p className="mono-label mt-6 text-muted">{hint}</p>
      </div>
    </section>
  );
}
