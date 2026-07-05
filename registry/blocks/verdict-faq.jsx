import React, { useState } from "react";
import { Eyebrow, TextLink } from "../lib/ui.jsx";
import { cn } from "../lib/cn.js";

/*
 * verdict-faq — zweispaltiges FAQ mit Accordion (useState).
 * Section-Typ: faq.  Keine Bild-Slots.
 * Props: { data } — Felder: title, body, footPrompt, footCta, items.
 */
export default function VerdictFaq({ data = {} }) {
  const { id = "faq", title, body, footPrompt, footCta, items = [] } = data;
  const [open, setOpen] = useState(0);
  return (
    <section id={id} className="section-padding">
      <div className="container-x grid gap-12 lg:grid-cols-2">
        <div className="lg:pr-12">
          <Eyebrow>FAQ</Eyebrow>
          <h2 className="display mt-6 text-[clamp(2rem,4.2vw,3.25rem)]">{title}</h2>
          <p className="mt-6 max-w-md text-[1.05rem] leading-relaxed text-muted">{body}</p>
          <hr className="my-8 border-line" />
          <p className="text-sm text-muted">{footPrompt}</p>
          <TextLink href="#" arrow="up" className="mt-2 text-accent">{footCta}</TextLink>
        </div>

        <div className="space-y-3">
          {items.map((it, i) => {
            const isOpen = i === open;
            return (
              <div key={i} className="overflow-hidden rounded-2xl bg-surface">
                <button
                  onClick={() => setOpen(isOpen ? -1 : i)}
                  className="flex w-full items-center justify-between gap-4 px-6 py-5 text-left"
                >
                  <span className="text-lg font-medium">{it.q}</span>
                  <span className={cn("shrink-0 text-muted transition-transform", isOpen && "rotate-180")}>⌄</span>
                </button>
                <div className={cn("grid transition-all duration-300", isOpen ? "grid-rows-[1fr]" : "grid-rows-[0fr]")}>
                  <div className="overflow-hidden">
                    <p className="px-6 pb-6 text-[1.02rem] leading-relaxed text-muted">{it.a}</p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
