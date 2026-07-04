import React from "react";
import { Logo } from "../lib/ui.jsx";

/*
 * verdict-footer — dunkler Footer mit 4-Spalten-Grid + Legal-Zeile.
 * Section-Typ: footer.  Keine Bild-Slots.
 * Props: { data } — Felder: tagline, firm, offices, contact, legal, license.
 */
function Col({ title, children }) {
  return (
    <div>
      <div className="mono-label text-paper/50">{title}</div>
      <div className="mt-5 space-y-3">{children}</div>
    </div>
  );
}

export default function VerdictFooter({ data = {} }) {
  const { id = "footer", tagline, firm = {}, offices = {}, contact = {}, legal, license } = data;
  return (
    <footer id={id} className="bg-ink pt-16 pb-10 text-paper md:pt-24 md:pb-12">
      <div className="container-x">
        <div className="grid gap-12 md:grid-cols-2 lg:grid-cols-4">
          <div className="max-w-xs">
            <Logo />
            <p className="mt-6 text-sm leading-relaxed text-paper/60">{tagline}</p>
          </div>

          <Col title={firm.title}>
            {(firm.links || []).map((l) => (
              <a key={l} href="#" className="block text-sm text-paper/80 hover:text-paper">{l}</a>
            ))}
          </Col>

          <Col title={offices.title}>
            {(offices.items || []).map((o) => (
              <div key={o.city}>
                <div className="text-sm font-medium">{o.city}</div>
                <div className="mt-0.5 text-sm text-paper/50">{o.addr}</div>
              </div>
            ))}
          </Col>

          <Col title={contact.title}>
            {(contact.links || []).map((l) => (
              <a key={l} href="#" className="block text-sm text-paper/80 hover:text-paper">{l}</a>
            ))}
          </Col>
        </div>

        <div className="mt-16 flex flex-col gap-4 border-t border-paper/10 pt-8 text-sm text-paper/50 md:flex-row md:items-center md:justify-between">
          <span>{legal}</span>
          <span className="flex items-center gap-2"><span className="h-1 w-1 rounded-full bg-accent" />{license}</span>
        </div>
      </div>
    </footer>
  );
}
