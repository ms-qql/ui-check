import { execFileSync } from "node:child_process";
import { cpSync, mkdirSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

// Verifikations-Build des komponierten Registry-Templates (Meridian-Branding).
// Voraussetzung: ./node_modules -> templates/verdict/poc/node_modules (esbuild + @tailwindcss/cli).
const root = path.dirname(fileURLToPath(import.meta.url));
const bin = path.join(root, "node_modules/.bin");
const dist = path.join(root, "dist");
rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });

execFileSync(path.join(bin, "esbuild"), [
  path.join(root, "main.jsx"), "--bundle", "--format=iife",
  "--jsx=automatic", "--loader:.js=jsx", `--outfile=${path.join(dist, "bundle.js")}`,
], { stdio: "inherit" });

execFileSync(path.join(bin, "tailwindcss"), [
  "-i", path.join(root, "preview.css"), "-o", path.join(dist, "styles.css"), "--minify",
], { stdio: "inherit", cwd: root });

// Fonts fürs lokale Rendern bereitstellen (self-hosted, DSGVO).
cpSync(path.join(root, "../../../../branding/meridian/fonts"), path.join(dist, "fonts"), { recursive: true });
cpSync(path.join(root, "index.html"), path.join(dist, "index.html"));
console.log("\n✓ Preview-Build →", path.relative(process.cwd(), dist));
