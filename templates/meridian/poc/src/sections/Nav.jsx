import React from "react";
import { Button, Logo } from "../lib/ui.jsx";

export default function Nav({ data = {} }) {
  const { links = [], cta } = data;
  return (
    <header className="fixed inset-x-0 top-0 z-50">
      <nav className="container-x flex items-center gap-8 py-5">
        <a href="#" className="text-paper"><Logo /></a>
        <ul className="ml-auto hidden items-center gap-8 text-sm text-paper/60 md:flex">
          {links.map((l) => (
            <li key={l}><a href="#" className="transition-colors hover:text-paper">{l}</a></li>
          ))}
        </ul>
        <Button variant="invert" size="md" className="ml-auto md:ml-0">{cta}</Button>
      </nav>
    </header>
  );
}
