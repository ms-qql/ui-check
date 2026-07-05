import React from "react";
import { nav } from "../content.js";
import { Button, Logo } from "../lib/ui.jsx";

export default function Nav() {
  return (
    <header className="fixed inset-x-0 top-4 z-50 px-4">
      <nav className="container-x">
        <div className="flex items-center gap-6 rounded-2xl bg-neutral-900/85 px-3 py-3 pl-5 text-white shadow-lg ring-1 ring-white/10 backdrop-blur">
          <a href="#" className="text-white"><Logo /></a>
          <ul className="ml-auto hidden items-center gap-8 text-sm text-white/80 md:flex">
            {nav.links.map((l) => (
              <li key={l}><a href="#" className="transition-colors hover:text-white">{l}</a></li>
            ))}
          </ul>
          <Button variant="invert" className="ml-auto md:ml-0">{nav.cta}</Button>
        </div>
      </nav>
    </header>
  );
}
