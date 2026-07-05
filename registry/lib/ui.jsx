import React from "react";
import { cn } from "./cn.js";

/* Eyebrow-Pill mit Bullet-Punkten (• Label •) */
export function Eyebrow({ children, className, dark }) {
  return (
    <span className={cn("eyebrow", dark && "border-paper/20 text-paper/80", className)}>
      {children}
    </span>
  );
}

/* Pill-Button (rounded-full) in mehreren Varianten — alle token-agnostisch */
export function Button({ children, variant = "primary", size = "md", className, as: As = "button", ...props }) {
  const base = "inline-flex items-center justify-center gap-2 rounded-full font-medium transition-colors whitespace-nowrap";
  const sizes = { md: "px-5 py-2.5 text-sm", lg: "px-6 py-3 text-[0.95rem]" };
  const variants = {
    primary: "bg-ink text-paper hover:bg-ink-soft",
    invert: "bg-paper text-ink hover:bg-surface",
    soft: "bg-surface text-ink hover:bg-line/60",
    ghostDark: "bg-paper/10 text-paper ring-1 ring-paper/15 backdrop-blur hover:bg-paper/20",
    outline: "border border-line text-ink hover:bg-surface",
  };
  return (
    <As className={cn(base, sizes[size], variants[variant], className)} {...props}>
      {children}
    </As>
  );
}

/* Text-Link mit Unterstrich */
export function TextLink({ children, className, arrow, ...props }) {
  return (
    <a className={cn("group inline-flex items-center gap-1.5 text-sm font-medium underline-offset-4 hover:underline", className)} {...props}>
      {children}
      {arrow && <span aria-hidden className="transition-transform group-hover:translate-x-0.5">{arrow === "up" ? "↗" : "→"}</span>}
    </a>
  );
}

/*
 * Bild-Slot (data-image-slot-Contract). Rendert einen neutralen Platzhalter,
 * bis ui-images-fill (PROJ-20) das Bild einsetzt. `id` MUSS einem image_slot
 * in content.json entsprechen. `src` ist optional (nur für lokale Previews).
 */
export function Slot({ id, className, src, alt = "", imgClass, children, dark }) {
  return (
    <div data-image-slot={id} className={cn("relative overflow-hidden", dark ? "bg-ink" : "bg-surface", className)}>
      {src ? (
        <img src={src} alt={alt} className={cn("h-full w-full object-cover", imgClass)} />
      ) : (
        <span className="mono-label absolute inset-0 grid place-items-center text-muted/60">{id}</span>
      )}
      {children}
    </div>
  );
}

/* Marken-Logo (V-Mark). `wordmark`-Text kommt aus dem Branding/Content. */
export function Logo({ className, word = "Verdict", wordmark = true }) {
  return (
    <span className={cn("inline-flex items-center gap-2.5", className)}>
      <svg viewBox="0 0 28 28" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth="1.4">
        <path d="M5 5 L14 22 L23 5" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M11 5 L14 11 L17 5" strokeLinecap="round" strokeLinejoin="round" opacity="0.9" />
      </svg>
      {wordmark && <span className="text-lg font-semibold tracking-tight">{word}</span>}
    </span>
  );
}
