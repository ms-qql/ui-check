import React from "react";
import { footer } from "../content.js";
import { Logo } from "../lib/ui.jsx";

function Col({ title, children }) {
  return (
    <div>
      <div className="mono-label text-white/50">{title}</div>
      <div className="mt-5 space-y-3">{children}</div>
    </div>
  );
}

export default function Footer() {
  return (
    <footer className="bg-neutral-950 pt-16 pb-10 text-white md:pt-24 md:pb-12">
      <div className="container-x">
        <div className="grid gap-12 md:grid-cols-2 lg:grid-cols-4">
          <div className="max-w-xs">
            <Logo />
            <p className="mt-6 text-sm leading-relaxed text-white/60">{footer.tagline}</p>
          </div>

          <Col title={footer.firm.title}>
            {footer.firm.links.map((l) => (
              <a key={l} href="#" className="block text-sm text-white/80 hover:text-white">{l}</a>
            ))}
          </Col>

          <Col title={footer.offices.title}>
            {footer.offices.items.map((o) => (
              <div key={o.city}>
                <div className="text-sm font-medium">{o.city}</div>
                <div className="mt-0.5 text-sm text-white/50">{o.addr}</div>
              </div>
            ))}
          </Col>

          <Col title={footer.contact.title}>
            {footer.contact.links.map((l) => (
              <a key={l} href="#" className="block text-sm text-white/80 hover:text-white">{l}</a>
            ))}
          </Col>
        </div>

        <div className="mt-16 flex flex-col gap-4 border-t border-white/10 pt-8 text-sm text-white/50 md:flex-row md:items-center md:justify-between">
          <span>{footer.legal}</span>
          <span className="flex items-center gap-2"><span className="h-1 w-1 rounded-full bg-accent" />{footer.license}</span>
        </div>
      </div>
    </footer>
  );
}
