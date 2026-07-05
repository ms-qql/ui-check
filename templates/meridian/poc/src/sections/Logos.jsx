import React from "react";
import { DispatchBar } from "../lib/ui.jsx";

export default function Logos({ data = {} }) {
  const { barLeft, barCenter, barRight, title = [], foot, items = [] } = data;
  return (
    <section id="logos" className="py-4">
      <DispatchBar left={barLeft} center={barCenter} right={barRight} />

      <div className="container-x pt-14">
        <h2 className="display text-[clamp(2.25rem,5vw,4rem)]">
          <span className="text-paper">{title[0]} </span><span className="text-muted">{title[1]}</span>
        </h2>

        <div className="mt-12 grid grid-cols-2 border-l border-t border-paper/12 md:grid-cols-4">
          {items.map((it) => (
            <div key={it.name} className="group relative flex h-40 items-center justify-center border-b border-r border-paper/12 transition-colors hover:bg-paper/[0.03]">
              <span className="text-lg font-semibold tracking-tight text-paper/45 transition-colors group-hover:text-paper/80" style={{ fontFamily: "var(--font-display)" }}>{it.name}</span>
              <span className="mono-label absolute bottom-3 right-3 text-paper/0 transition-colors group-hover:text-paper/30">{it.est}</span>
            </div>
          ))}
        </div>

        <div className="mt-8 flex items-end justify-between border-t border-paper/12 pt-6">
          <p className="text-lg text-muted">{foot}</p>
          <span className="mono-label text-paper/30">Quiet</span>
        </div>
      </div>
    </section>
  );
}
