import React from "react";
import { Button, DispatchBar } from "../lib/meridian-ui.jsx";

/*
 * meridian-footer — Dispatch-Bar, Riesen-Wortmarke (paper→muted-Verlauf),
 * Intro + Newsletter (Glow-CTA), drei Link-Spalten, Rechtszeile.
 * Section-Typ: footer.  Keine Bild-Slots.
 * Props: { data } — Felder: barLeft/Center/Right, wordmark, body, emailPlaceholder, subscribe, emailNote, cols[], copyright, contact, social[].
 */
export default function MeridianFooter({ data = {} }) {
  const { id = "footer", barLeft, barCenter, barRight, wordmark, body, emailPlaceholder, subscribe, emailNote, cols = [], copyright, contact, social = [] } = data;
  return (
    <footer id={id} className="relative overflow-hidden bg-ink pt-4 text-paper">
      <DispatchBar left={barLeft} center={barCenter} right={barRight} />

      <div className="container-x pt-14">
        <div className="display bg-gradient-to-r from-paper via-paper to-muted bg-clip-text text-center text-[clamp(4rem,20vw,16rem)] font-bold leading-none text-transparent">
          {wordmark}
        </div>

        <div className="mt-10 flex flex-col items-center text-center">
          <span className="h-9 w-9 rounded-full bg-paper/80" />
          <p className="mt-8 max-w-md leading-relaxed text-muted">{body}</p>
        </div>

        <div className="mx-auto mt-10 max-w-lg text-center">
          <div className="flex items-center gap-3">
            <input
              placeholder={emailPlaceholder}
              className="mono-label flex-1 rounded-full border border-paper/20 bg-transparent px-5 py-3 text-paper placeholder:text-paper/40 focus:border-paper/40 focus:outline-none"
            />
            <Button variant="primary" glow>{subscribe}</Button>
          </div>
          <div className="mono-label mt-3 text-paper/35">{emailNote}</div>
        </div>

        <div className="mt-20 grid grid-cols-2 gap-8 border-t border-paper/12 pt-10 md:grid-cols-3">
          {cols.map((c) => (
            <div key={c.head}>
              <div className="mono-label text-paper/35">{c.head}</div>
              <ul className="mt-4 space-y-2">
                {c.links.map((l) => (
                  <li key={l}><a href="#" className="mono-label text-paper/70 transition-colors hover:text-paper">{l}</a></li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mono-label flex flex-col items-center justify-between gap-4 border-t border-paper/12 py-8 text-paper/40 md:flex-row">
          <span>{copyright}</span>
          <a href="#" className="hover:text-paper">{contact}</a>
          <span className="flex gap-5">{social.map((s) => <a key={s} href="#" className="hover:text-paper">{s}</a>)}</span>
        </div>
      </div>
    </footer>
  );
}
