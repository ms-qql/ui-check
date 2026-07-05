import React from "react";
import { Button } from "../lib/ui.jsx";

/* Faux-Dashboard-Chrome — im Original ein perspektivisch gekipptes Produkt-Bild.
   Wird in der Registry-Fassung durch einen Slot (hero-visual) ersetzt. */
function DashboardMock() {
  const nav = ["Dashboard", "Projects", "Team", "Reports", "Settings"];
  const tiles = [
    { k: "TOTAL REVENUE", v: "$45,231", d: "+20.1% from last month" },
    { k: "SUBSCRIPTIONS", v: "2,350", d: "+12.2% from last month" },
    { k: "ACTIVE USERS", v: "18,942", d: "+5.4% from last month" },
  ];
  const sales = ["Olivia Martin", "Jackson Lee", "Isabella Nguyen", "William Kim", "Sofia Davis"];
  return (
    <div className="rounded-t-xl border border-paper/10 bg-ink-soft/60 text-paper/70 shadow-2xl">
      <div className="mono-label flex items-center gap-2 border-b border-paper/10 px-5 py-3 text-paper/40">
        <span className="flex gap-1.5">{[0,1,2].map((i)=><span key={i} className="h-2 w-2 rounded-full bg-paper/20" />)}</span>
        <span className="ml-3">acme · dashboard</span>
      </div>
      <div className="grid grid-cols-[180px_1fr_200px]">
        <aside className="space-y-1 border-r border-paper/10 p-4">
          <div className="mb-4 flex items-center gap-2 text-paper/80"><span className="h-5 w-5 rounded bg-paper/10" /> <span className="text-sm font-medium">Acme Inc</span></div>
          {nav.map((n, i) => (
            <div key={n} className={`rounded px-3 py-1.5 text-sm ${i===0 ? "bg-paper/10 text-paper" : "text-paper/50"}`}>{n}</div>
          ))}
        </aside>
        <div className="space-y-4 p-5">
          <div className="mono-label flex gap-6 border-b border-paper/10 pb-2 text-paper/40">
            {["Overview","Analytics","Customers","Products"].map((t,i)=><span key={t} className={i===0?"text-paper":""}>{t}</span>)}
          </div>
          <div className="grid grid-cols-3 gap-3">
            {tiles.map((t) => (
              <div key={t.k} className="rounded-lg border border-paper/10 p-3">
                <div className="mono-label text-paper/40">{t.k}</div>
                <div className="mt-1 text-xl font-medium text-paper" style={{fontFamily:"var(--font-display)"}}>{t.v}</div>
                <div className="mono-label mt-1 text-paper/30">{t.d}</div>
              </div>
            ))}
          </div>
          <div className="rounded-lg border border-paper/10 p-4">
            <div className="mono-label text-paper/40">REVENUE · 2025</div>
            <div className="mt-2 flex items-end gap-1.5">
              {[40,55,35,70,50,80,60,90,65,75,85,95].map((h,i)=>(
                <span key={i} style={{height:`${h}px`}} className="w-full rounded-sm bg-paper/15" />
              ))}
            </div>
          </div>
        </div>
        <aside className="space-y-3 border-l border-paper/10 p-4">
          <div className="mono-label text-paper/40">RECENT SALES</div>
          {sales.map((s) => (
            <div key={s} className="flex items-center gap-2">
              <span className="h-6 w-6 rounded-full bg-paper/10" />
              <span className="text-xs text-paper/70">{s}</span>
            </div>
          ))}
        </aside>
      </div>
    </div>
  );
}

export default function Hero({ data = {} }) {
  const { title = [], body, ctas = [] } = data;
  return (
    <section id="hero" className="relative overflow-hidden bg-ink pt-36 text-paper">
      <div className="container-x">
        <h1 className="display max-w-4xl text-[clamp(2.75rem,7vw,5.5rem)]">
          {title.map((t, i) => <span key={i} className="block">{t}</span>)}
        </h1>
        <p className="mt-8 max-w-xl text-lg leading-relaxed text-muted">{body}</p>
        <div className="mt-10 flex flex-wrap items-center gap-6">
          {ctas.map((c) => (
            <Button key={c.label} size="lg" variant={c.variant} glow={c.glow}>{c.label}</Button>
          ))}
        </div>
      </div>
      {/* Perspektivisch gekipptes Produkt-Fenster */}
      <div className="container-x mt-20" style={{ perspective: "2000px" }}>
        <div style={{ transform: "rotateX(32deg) rotateZ(-8deg) scale(1.05)", transformOrigin: "center top" }} className="mx-auto max-w-6xl">
          <DashboardMock />
        </div>
      </div>
    </section>
  );
}
