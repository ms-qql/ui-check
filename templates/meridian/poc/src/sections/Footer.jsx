import React from "react";
import { Button, DispatchBar } from "../lib/ui.jsx";

export default function Footer({ data = {} }) {
  const { barLeft, barCenter, barRight, wordmark, body, emailPlaceholder, subscribe, emailNote, cols = [], copyright, contact, social = [] } = data;
  return (
    <footer className="relative overflow-hidden bg-ink pt-4 text-paper">
      <DispatchBar left={barLeft} center={barCenter} right={barRight} />

      <div className="container-x pt-14">
        {/* Riesen-Wortmarke */}
        <div
          className="display text-center text-[clamp(4rem,20vw,16rem)] leading-none"
          style={{ background: "linear-gradient(100deg,#ffffff 55%,#8f8f8f 100%)", WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent", fontWeight: 700 }}
        >
          {wordmark}
        </div>

        {/* Kreis + Intro */}
        <div className="mt-10 flex flex-col items-center text-center">
          <span className="h-9 w-9 rounded-full bg-paper/80" />
          <p className="mt-8 max-w-md leading-relaxed text-muted">{body}</p>
        </div>

        {/* Newsletter */}
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

        {/* Link-Spalten */}
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

        {/* Fußzeile */}
        <div className="mono-label flex flex-col items-center justify-between gap-4 border-t border-paper/12 py-8 text-paper/40 md:flex-row">
          <span>{copyright}</span>
          <a href="#" className="hover:text-paper">{contact}</a>
          <span className="flex gap-5">{social.map((s) => <a key={s} href="#" className="hover:text-paper">{s}</a>)}</span>
        </div>
      </div>
    </footer>
  );
}
