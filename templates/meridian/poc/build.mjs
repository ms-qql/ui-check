import * as esbuild from "esbuild";
import { execFileSync } from "node:child_process";
import { cpSync, mkdirSync, copyFileSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.dirname(fileURLToPath(import.meta.url));
const dist = path.join(root, "dist");
rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });

// 1) JS-Bundle (React 19, IIFE)
await esbuild.build({
  entryPoints: [path.join(root, "src/main.jsx")],
  bundle: true,
  format: "iife",
  jsx: "automatic",
  loader: { ".js": "jsx" },
  outfile: path.join(dist, "bundle.js"),
  logLevel: "info",
});

// 2) Tailwind-CSS (v4 CLI, Auto-Content-Scan)
execFileSync(
  path.join(root, "node_modules/.bin/tailwindcss"),
  ["-i", path.join(root, "src/index.css"), "-o", path.join(dist, "styles.css"), "--minify"],
  { stdio: "inherit", cwd: root }
);

// 3) Assets + HTML
cpSync(path.join(root, "public/assets"), path.join(dist, "assets"), { recursive: true });
copyFileSync(path.join(root, "index.html"), path.join(dist, "index.html"));

console.log("\n✓ Build fertig →", path.relative(process.cwd(), dist));
