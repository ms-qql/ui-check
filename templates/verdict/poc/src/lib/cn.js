// Minimal className joiner (POC — ohne clsx/tailwind-merge-Abhängigkeit).
export function cn(...args) {
  return args.flat(Infinity).filter(Boolean).join(" ");
}
