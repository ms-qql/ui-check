import React from "react";
import { cn } from "./cn.js";

/*
 * Meridian-Primitives (token-agnostisch). Nur semantische Tokens
 * (paper/ink/ink-soft/muted/surface/line/accent/accent-soft/sand + radius,
 * font-sans/display/mono). Keine Tailwind-Default-Palette, kein Roh-Hex.
 * Geteilt von allen meridian-* Blocks; Look kommt aus branding/meridian/.
 */

/* Marken-Wortmarke mit Globus-Glyph + ®. */
export function Logo({ className, word = "Meridian", mark = true }) {
  return (
    <span className={cn("inline-flex items-center gap-2.5", className)}>
      {mark && (
        <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth="1.3">
          <circle cx="12" cy="12" r="9" />
          <ellipse cx="12" cy="12" rx="4" ry="9" />
          <path d="M3 12h18M4.5 7h15M4.5 17h15" />
        </svg>
      )}
      <span className="font-display text-lg font-medium tracking-tight">
        {word}
        <sup className="ml-0.5 align-super text-[0.55em] opacity-60">®</sup>
      </span>
    </span>
  );
}

/*
 * Pill-Button mit optionalem irisierendem Glow (Meridian-Signatur).
 * variant: primary (heller Pill) · invert (dunkler Pill) · quiet (Text + Pfeil) · outline.
 */
export function Button({ children, variant = "primary", size = "md", glow, className, as: As = "button", ...props }) {
  const base = "relative inline-flex items-center justify-center gap-2 rounded-full font-medium transition-colors whitespace-nowrap";
  const sizes = { md: "px-5 py-2.5 text-sm", lg: "px-7 py-3.5 text-[0.95rem]" };
  const variants = {
    primary: "bg-paper text-ink hover:bg-surface",
    invert: "bg-ink text-paper ring-1 ring-paper/15 hover:bg-ink-soft",
    quiet: "px-0 text-paper hover:text-paper/70",
    outline: "border border-paper/20 text-paper hover:bg-paper/10",
  };
  const btn = (
    <As className={cn(base, variant !== "quiet" && sizes[size], variants[variant], className)} {...props}>
      {children}
      {variant === "quiet" && <span aria-hidden className="transition-transform">→</span>}
    </As>
  );
  if (!glow) return btn;
  return (
    <span className="relative inline-flex">
      <span aria-hidden className="absolute -inset-[3px] rounded-full bg-gradient-to-r from-accent via-accent-soft to-accent opacity-70 blur-md" />
      {btn}
    </span>
  );
}

/* Text-Link mit Pfeil. */
export function TextLink({ children, className, arrow = "→", ...props }) {
  return (
    <a className={cn("group inline-flex items-center gap-1.5 text-sm font-medium transition-colors hover:text-paper", className)} {...props}>
      {children}
      {arrow && <span aria-hidden className="transition-transform group-hover:translate-x-0.5">{arrow}</span>}
    </a>
  );
}

/*
 * Dispatch-Strip: wiederkehrende Kopf-Metazeile — drei Mono-Labels
 * (links mit ●, mittig, rechts) über einer Haarlinie, optional Punktraster.
 */
export function DispatchBar({ left, center, right, dotted, className }) {
  return (
    <div className={cn("relative w-full", className)}>
      {dotted && <div aria-hidden className="dot-grid absolute inset-0 text-paper/20 opacity-40" />}
      <div className="relative container-x flex items-center justify-between gap-4 py-4 text-paper/45">
        <span className="mono-label flex items-center gap-2">
          {left && <span aria-hidden className="h-1.5 w-1.5 rounded-full bg-paper/60" />} {left}
        </span>
        <span className="mono-label hidden md:block">{center}</span>
        <span className="mono-label text-right">{right}</span>
      </div>
      <div className="relative container-x"><div className="border-t border-paper/15" /></div>
    </div>
  );
}

/* Spec-Card: bordierte Mono-Datenkarte (§ MRD / 01 … Label/Wert-Zeilen). */
export function SpecCard({ head, rows = [], className }) {
  return (
    <div className={cn("rounded-md border border-paper/15 bg-paper/[0.02] p-4 text-paper/70", className)}>
      {head && (
        <div className="mono-label flex items-center justify-between border-b border-paper/10 pb-3 text-paper/80">
          <span>{head.title}</span>
          <span className="text-paper/45">{head.tag}</span>
        </div>
      )}
      <dl className="mt-1 divide-y divide-paper/5">
        {rows.map((r) => (
          <div key={r.k} className="mono-label flex items-center justify-between py-2.5">
            <dt className="text-paper/45">{r.k}</dt>
            <dd className="text-paper/90">{r.v}</dd>
          </div>
        ))}
      </dl>
    </div>
  );
}

/* Faux-Barcode (deterministisch aus Seed) — für Ticket/Receipt-Karten. */
export function Barcode({ seed = "MERIDIAN", className, dark }) {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) >>> 0;
  const bars = Array.from({ length: 54 }, () => {
    h = (h * 1103515245 + 12345) >>> 0;
    return 1 + (h % 4);
  });
  return (
    <div className={cn("flex h-9 items-end gap-[2px]", className)} aria-hidden>
      {bars.map((w, i) => (
        <span key={i} style={{ width: `${w}px` }} className={cn("h-full", dark ? "bg-ink/80" : "bg-paper/80", i % 7 === 0 && "h-2/3")} />
      ))}
    </div>
  );
}

/*
 * Bild-Slot (data-image-slot-Contract). Neutraler Platzhalter bis
 * ui-images-fill (PROJ-20) das Bild einsetzt. `src` nur für lokale Previews.
 */
export function Slot({ id, className, src, alt = "", imgClass, children, dark = true }) {
  return (
    <div data-image-slot={id} className={cn("relative overflow-hidden", dark ? "bg-ink-soft" : "bg-surface", className)}>
      {src ? (
        <img src={src} alt={alt} className={cn("h-full w-full object-cover", imgClass)} />
      ) : (
        <span className="mono-label absolute inset-0 grid place-items-center text-paper/25">{id}</span>
      )}
      {children}
    </div>
  );
}
