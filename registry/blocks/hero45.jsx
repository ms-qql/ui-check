import React, { useState } from "react";
import { cn } from "../lib/cn.js";
import { Slot } from "../lib/ui.jsx";

/*
 * hero45 — Hero mit Outline-Badge, Headline, breitem Landscape-Bild (gerundet,
 * unten ausgeblendet) und drei icon-geführten Feature-Spalten. Das Bild
 * crossfadet, sobald eine Feature-Spalte gehovert wird; auf Desktop trennen
 * vertikale Verläufe die Spalten.
 *
 * Quelle: shadcnblocks.com/block/hero45 (free) — token-agnostisch überführt
 * (shadcn-Default-Tokens → UI-Check-Semantik-Tokens, lucide → inline-SVG,
 * Foto-URLs → Slot-Platzhalter). Kein next/*, Dep nur react.
 *
 * Section-Typ: hero.  Bild-Slots: eins je Feature (siehe demo.features[].imageSlot).
 * Props: { data } aus content.json — Fallback ist der `demo`-Export.
 */

const ICONS = {
  braces: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5">
      <path d="M8 3H7a2 2 0 0 0-2 2v5a2 2 0 0 1-2 2 2 2 0 0 1 2 2v5a2 2 0 0 0 2 2h1" />
      <path d="M16 3h1a2 2 0 0 1 2 2v5a2 2 0 0 0 2 2 2 2 0 0 0-2 2v5a2 2 0 0 1-2 2h-1" />
    </svg>
  ),
  cpu: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5">
      <rect x="4" y="4" width="16" height="16" rx="2" />
      <rect x="9" y="9" width="6" height="6" />
      <path d="M15 2v2M9 2v2M15 20v2M9 20v2M2 15h2M2 9h2M20 15h2M20 9h2" />
    </svg>
  ),
  keyboard: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5">
      <rect x="2" y="6" width="20" height="12" rx="2" />
      <path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M6 14h.01M18 14h.01M9 14h6" />
    </svg>
  ),
};

export const demo = {
  id: "hero",
  type: "hero",
  badge: "Platform",
  heading: "Shadcn UI Components built for the modern stack.",
  features: [
    { title: "Composable patterns", description: "Ship faster with structured sections and consistent spacing.", icon: "braces", imageSlot: "hero45-visual-1" },
    { title: "Design tokens", description: "Theme and scale colors, type, and radii from a single coherent system.", icon: "cpu", imageSlot: "hero45-visual-2" },
    { title: "Accessible defaults", description: "Keyboard and screen-reader friendly building blocks out of the box.", icon: "keyboard", imageSlot: "hero45-visual-3" },
  ],
};

export default function Hero45({ data = {} }) {
  const { id = "hero", badge, heading, features = [] } = { ...demo, ...data };
  const visible = features.slice(0, 3);
  const [active, setActive] = useState(0);

  return (
    <section id={id} className="section-padding bg-paper text-ink">
      <div className="container-x overflow-hidden">
        <div className="mb-20 flex flex-col items-center gap-6 text-center">
          {badge && (
            <span className="inline-flex items-center rounded-[var(--radius)] border border-line px-2.5 py-0.5 text-xs font-medium text-muted">
              {badge}
            </span>
          )}
          <h1 className="display max-w-3xl text-4xl text-pretty lg:text-5xl">{heading}</h1>
        </div>

        <div className="relative mx-auto max-w-5xl">
          <div className="relative aspect-video max-h-[500px] w-full">
            <div className="absolute inset-0 overflow-hidden rounded-[var(--radius)]">
              {visible.map((f, i) => (
                <Slot
                  key={f.imageSlot || i}
                  id={f.imageSlot || `hero45-visual-${i + 1}`}
                  className={cn(
                    "absolute inset-0 rounded-[var(--radius)] border border-line transition-opacity duration-500 ease-out",
                    active === i ? "z-10 opacity-100" : "pointer-events-none z-0 opacity-0",
                  )}
                  imgClass="object-top"
                />
              ))}
            </div>
            {/* Verlauf: Bildkante nach unten ausblenden */}
            <div className="pointer-events-none absolute inset-0 z-20 rounded-[var(--radius)] bg-gradient-to-t from-paper via-transparent to-transparent" />
            {/* dezentes Punktraster in den oberen Ecken */}
            <div className="pointer-events-none absolute -top-28 -right-28 -z-10 h-72 w-96 opacity-40 [background:radial-gradient(var(--color-muted)_1px,transparent_1px)] [background-size:12px_12px] [mask-image:radial-gradient(ellipse_50%_50%_at_50%_50%,#000_20%,transparent_100%)]" />
            <div className="pointer-events-none absolute -top-28 -left-28 -z-10 h-72 w-96 opacity-40 [background:radial-gradient(var(--color-muted)_1px,transparent_1px)] [background-size:12px_12px] [mask-image:radial-gradient(ellipse_50%_50%_at_50%_50%,#000_20%,transparent_100%)]" />
          </div>
        </div>

        <div className="mx-auto mt-10 flex max-w-5xl flex-col md:flex-row" onMouseLeave={() => setActive(0)}>
          {visible.map((f, i) => (
            <React.Fragment key={f.title}>
              {i > 0 && (
                <div className="mx-6 hidden w-0.5 self-stretch bg-gradient-to-b from-line via-transparent to-line md:block" />
              )}
              <div
                className="flex grow basis-0 cursor-default flex-col rounded-[var(--radius)] bg-paper p-4 transition-colors hover:bg-surface"
                onMouseEnter={() => setActive(i)}
              >
                <div className="mb-6 flex size-10 items-center justify-center rounded-full bg-paper text-ink drop-shadow-lg">
                  {ICONS[f.icon] || ICONS.braces}
                </div>
                <h3 className="mb-2 font-semibold tracking-tight text-ink">{f.title}</h3>
                <p className="text-sm text-pretty text-muted">{f.description}</p>
              </div>
            </React.Fragment>
          ))}
        </div>
      </div>
    </section>
  );
}
