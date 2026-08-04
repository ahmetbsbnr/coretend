#!/usr/bin/env node
/** Ahmet Design System — assemble dist/ depuis src/.
 *
 *  Usage :
 *    node build.mjs          # écrit dist/ahmet-design.css + dist/ahmet-design-motion.js
 *    node build.mjs --check  # vérifie que dist/ est à jour (exit 1 sinon)
 *
 *  L'ordre de la cascade est l'ordre numérique des sections (01 → 21).
 *  themes.css est inséré après la section 02 (mécanique de transition de
 *  thème appartenant au reset). dist/ahmet-design-motion.js est la copie de
 *  src/core-bloom.js. */

import { readFileSync, writeFileSync, mkdirSync, existsSync, copyFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = dirname(fileURLToPath(import.meta.url));
const SRC = join(ROOT, "src");
const DIST = join(ROOT, "dist");

const HEADER = `/* ============================================================
   Ahmet Design System 1.0.0
   Canonical visual language for ahmetbsbnr products.
   Source of truth: CoreTend product site (ahmetbsbnr/coretend,
   Website/index.html) at commit 63cd103.
   License: Apache-2.0 (see PROVENANCE.md). Fonts: OFL-1.1.
   ------------------------------------------------------------
   Section index:
   01 tokens (light/dark)   02 reset + base      03 typography
   04 layout                05 ambient layers    06 reveal + motion
   07 buttons               08 header bar        09 hero
   10 product frame (.app)  11 ticker            12 workflow/steps
   13 modules               14 findings/slabs    15 gauges
   16 facts + terminal      17 faq               18 closing + footer
   19 toast/skip/rail       20 reduced motion    21 responsive
   Généré par build.mjs — ne pas éditer à la main.
   ============================================================ */

`;

const FILES = ["tokens.css", "reset.css", "themes.css", "typography.css", "layout.css", "motion.css", "components.css", "surfaces.css", "responsive.css"];

const sections = new Map();
let themesBody = "";

for (const file of FILES) {
  const text = readFileSync(join(SRC, file), "utf8");
  const body = text.slice(text.indexOf("/* ----------") >= 0 ? text.indexOf("/* ----------") : text.indexOf("*/") + 2);
  const re = /\/\* ---------- (\d{2}) [^-]*---------- \*\//g;
  const found = [...body.matchAll(re)];
  if (!found.length) {
    // themes.css est un fichier de contrat (documentation) : il ne contribue
    // aucune règle au dist — les valeurs vivent dans tokens.css et la
    // mécanique de transition dans reset.css.
    if (file === "themes.css") {
      themesBody = "";
      continue;
    }
    throw new Error(`aucune section dans ${file}`);
  }
  found.forEach((m, i) => {
    const end = i + 1 < found.length ? found[i + 1].index : body.length;
    sections.set(m[1], body.slice(m.index, end).replace(/\s+$/, "") + "\n\n");
  });
}

const ordered = [...sections.keys()].sort();
if (ordered.length !== 21) throw new Error(`21 sections attendues, ${ordered.length} trouvées`);
let css = HEADER;
for (const key of ordered) {
  css += sections.get(key);
  if (key === "02") css += themesBody;
}
css = css.replace(/\n\n$/, "\n");

const js = readFileSync(join(SRC, "core-bloom.js"), "utf8");

if (process.argv.includes("--check")) {
  const currentCss = existsSync(join(DIST, "ahmet-design.css")) ? readFileSync(join(DIST, "ahmet-design.css"), "utf8") : "";
  const currentJs = existsSync(join(DIST, "ahmet-design-motion.js")) ? readFileSync(join(DIST, "ahmet-design-motion.js"), "utf8") : "";
  if (currentCss !== css || currentJs !== js) {
    console.error("[design-system] dist/ n'est pas à jour — lancer `node build.mjs`.");
    process.exit(1);
  }
  console.log("[design-system] dist/ à jour.");
} else {
  mkdirSync(DIST, { recursive: true });
  writeFileSync(join(DIST, "ahmet-design.css"), css);
  writeFileSync(join(DIST, "ahmet-design-motion.js"), js);
  console.log(`[design-system] dist/ généré (${css.length} octets CSS, ${js.length} octets JS).`);
}
