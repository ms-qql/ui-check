import React, { useState } from "react";
import { faq } from "../content.js";
import { Eyebrow, TextLink } from "../lib/ui.jsx";
import { cn } from "../lib/cn.js";

export default function Faq() {
  const [open, setOpen] = useState(0);
  return (
    <section className="section-padding">
      <div className="container-x grid gap-12 lg:grid-cols-2">
        <div className="lg:pr-12">
          <Eyebrow>FAQ</Eyebrow>
          <h2 className="display mt-6 text-[clamp(2rem,4.2vw,3.25rem)]">{faq.title}</h2>
          <p className="mt-6 max-w-md text-[1.05rem] leading-relaxed text-muted">{faq.body}</p>
          <hr className="my-8 border-line" />
          <p className="text-sm text-muted">{faq.footPrompt}</p>
          <TextLink href="#" arrow="up" className="mt-2 text-accent">{faq.footCta}</TextLink>
        </div>

        <div className="space-y-3">
          {faq.items.map((it, i) => {
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
