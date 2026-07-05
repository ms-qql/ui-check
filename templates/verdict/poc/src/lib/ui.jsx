import React from "react";
import { cn } from "./cn.js";

/* Eyebrow-Pill mit Bullet-Punkten (• Label •) */
export function Eyebrow({ children, className, dark }) {
  return (
    <span className={cn("eyebrow", dark && "border-white/20 text-white/80", className)}>
      {children}
    </span>
  );
}

/* Pill-Button (rounded-full) in mehreren Varianten */
export function Button({ children, variant = "primary", size = "md", className, as: As = "button", ...props }) {
  const base = "inline-flex items-center justify-center gap-2 rounded-full font-medium transition-colors whitespace-nowrap";
  const sizes = { md: "px-5 py-2.5 text-sm", lg: "px-6 py-3 text-[0.95rem]" };
  const variants = {
    primary: "bg-ink text-paper hover:bg-ink-soft",
    invert: "bg-paper text-ink hover:bg-surface",
    soft: "bg-surface text-ink hover:bg-line/60",
    ghostDark: "bg-white/10 text-white ring-1 ring-white/15 backdrop-blur hover:bg-white/20",
    outline: "border border-line text-ink hover:bg-surface",
  };
  return (
    <As className={cn(base, sizes[size], variants[variant], className)} {...props}>
      {children}
    </As>
  );
}

/* Text-Link mit Unterstrich-Underline */
export function TextLink({ children, className, arrow, ...props }) {
  return (
    <a className={cn("group inline-flex items-center gap-1.5 text-sm font-medium underline-offset-4 hover:underline", className)} {...props}>
      {children}
      {arrow && <span aria-hidden className="transition-transform group-hover:translate-x-0.5">{arrow === "up" ? "↗" : "→"}</span>}
    </a>
  );
}

/* V-Logo-Mark (SVG, an das Original angelehnt) */
export function Logo({ className, wordmark = true }) {
  return (
    <span className={cn("inline-flex items-center gap-2.5", className)}>
      <svg viewBox="0 0 28 28" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth="1.4">
        <path d="M5 5 L14 22 L23 5" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M11 5 L14 11 L17 5" strokeLinecap="round" strokeLinejoin="round" opacity="0.9" />
      </svg>
      {wordmark && <span className="text-lg font-semibold tracking-tight">Verdict</span>}
    </span>
  );
}
