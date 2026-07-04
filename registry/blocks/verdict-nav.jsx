import React from "react";
import { Button, Logo } from "../lib/ui.jsx";

/*
 * verdict-nav — schwebende Pill-Navigation (dunkel, backdrop-blur).
 * Section-Typ: nav.  Keine Bild-Slots.
 * Props: { data } — Felder: links, cta.
 */
export default function VerdictNav({ data = {} }) {
  const { id = "nav", links = [], cta } = data;
  return (
    <header id={id} className="fixed inset-x-0 top-4 z-50 px-4">
      <nav className="container-x">
        <div className="flex items-center gap-6 rounded-2xl bg-ink/90 px-3 py-3 pl-5 text-paper shadow-lg ring-1 ring-paper/10 backdrop-blur">
          <a href="#" className="text-paper"><Logo /></a>
          <ul className="ml-auto hidden items-center gap-8 text-sm text-paper/80 md:flex">
            {links.map((l) => (
              <li key={l}><a href="#" className="transition-colors hover:text-paper">{l}</a></li>
            ))}
          </ul>
          <Button variant="invert" className="ml-auto md:ml-0">{cta}</Button>
        </div>
      </nav>
    </header>
  );
}
