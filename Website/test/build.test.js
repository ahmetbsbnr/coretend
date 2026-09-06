// SPDX-License-Identifier: Apache-2.0
// Build-output assertions: runs `python3 build.py` into a temp dir once and
// checks the generated site for the properties this vertical guarantees.
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const { mkdtempSync, readFileSync, readdirSync, existsSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { join } = require("node:path");

const SITE = join(__dirname, "..");
let OUT;

test.before(() => {
  OUT = mkdtempSync(join(tmpdir(), "coretend-build-"));
  execFileSync("python3", ["build.py", "--output", OUT], { cwd: SITE, stdio: "pipe" });
});

const read = (f) => readFileSync(join(OUT, f), "utf8");
const htmlFiles = () => readdirSync(OUT).filter((f) => f.endsWith(".html"));

test("every expected route is generated (EN + FR)", () => {
  for (const f of [
    "index.html", "en-route.html", "fr-route.html",
    "privacy.html", "support.html", "legal.html", "licenses.html",
    "contact.html", "community.html", "security.html", "changelog.html",
    "fr-privacy.html", "fr-support.html", "fr-contact.html", "fr-community.html",
    "fr-security.html", "fr-changelog.html",
    "404.html",
  ]) {
    assert.ok(existsSync(join(OUT, f)), `missing ${f}`);
  }
});

test("Privacy page distinguishes the app from Contact/Community transmission", () => {
  const t = read("privacy.html");
  assert.match(t, /Contact and Community/);
  assert.match(t, /only when you send it/i);
  assert.match(t, /Nothing is taken from your Mac automatically/i);
  assert.match(t, /privacy@ahmetbsbnr\.com/);
});

test("Security page explains trust without crypto steps; signed != safe", () => {
  const t = read("security.html");
  assert.match(t, /Developer ID/);
  assert.match(t, /does not mean .safe/i);
  assert.match(t, /Trash by default/i);
  assert.match(t, /security@ahmetbsbnr\.com/);
  assert.ok(!/minisign|SHA-?256|shasum/i.test(t));
});

test("Changelog: 1.1.0-beta.1 is marked unreleased with no invented date", () => {
  const t = read("changelog.html");
  assert.match(t, /1\.1\.0-beta\.1/);
  assert.match(t, /unreleased/i);
  // The only date present is the real v1.0.0 publish date.
  const dates = t.match(/20\d\d-\d\d-\d\d/g) || [];
  assert.deepEqual([...new Set(dates)], ["2026-09-03"]);
});

test("CSP unchanged: form-action stays 'none' (forms are fetch-based)", () => {
  const cfg = JSON.parse(readFileSync(join(SITE, "vercel.json"), "utf8"));
  const csp = cfg.headers[0].headers.find((h) => h.key === "Content-Security-Policy").value;
  assert.match(csp, /form-action 'none'/);
  assert.match(csp, /connect-src 'self'/);
  assert.ok(!csp.includes("*"), "no wildcard in the CSP");
});

test("no crypto / verification clutter on any user page", () => {
  for (const f of htmlFiles()) {
    const t = read(f);
    for (const bad of ["minisign", "SHA256SUMS", "shasum", "xcrun stapler", "spctl "]) {
      assert.ok(!t.includes(bad), `${f} contains "${bad}"`);
    }
    assert.ok(!/SHA-?256/i.test(t.replace(/latest\.json/g, "")), `${f} mentions SHA-256`);
  }
  for (const f of readdirSync(join(OUT, "assets/generated"))) {
    assert.ok(!/SHA-?256|minisign/i.test(read(join("assets/generated", f))), `${f}`);
  }
});

test("no AI-assistant credit line anywhere in the output", () => {
  for (const f of htmlFiles()) {
    assert.ok(!/Claude \(Anthropic\)|supervised assistant/i.test(read(f)), f);
  }
});

test("no simulated security dialog text", () => {
  for (const f of htmlFiles()) {
    assert.ok(!/checked it for malicious software|Developer ID verified/i.test(read(f)), f);
  }
});

test("Contact page: fetch-based form, all request types, honeypot, no mailto", () => {
  const t = read("contact.html");
  assert.match(t, /data-api-form="\/api\/contact"/);
  for (const v of ["general", "support", "bug", "improvement", "feature", "privacy", "security"]) {
    assert.match(t, new RegExp(`value="${v}"`));
  }
  assert.match(t, /name="company"/); // honeypot
  assert.ok(!/href="mailto:/.test(t), "no mailto fallback in the form");
  assert.match(t, /CoreTend never attaches anything from your Mac/i);
});

test("Community page: feed + submit form with un-checked public consent", () => {
  const t = read("community.html");
  assert.match(t, /id="community-feed"/);
  assert.match(t, /data-api-form="\/api\/community"/);
  assert.match(t, /name="publicConsent"/);
  assert.ok(!/name="publicConsent"[^>]*checked/.test(t), "consent must not be pre-checked");
  assert.match(t, /name="website"/); // honeypot
});

test("nav + footer expose Community and Contact on every shell page", () => {
  for (const f of ["privacy.html", "support.html", "contact.html", "community.html"]) {
    const t = read(f);
    assert.match(t, /href="\/community"/);
    assert.match(t, /href="\/contact"/);
    assert.match(t, /href="\/download"/);
  }
});

test("sitemap lists the new routes; robots allows crawling", () => {
  const sm = read("sitemap.xml");
  for (const p of ["/contact", "/community", "/fr/contact", "/fr/community"]) {
    assert.ok(sm.includes(`<loc>https://coretend.ahmetbsbnr.com${p}</loc>`), p);
  }
  assert.match(read("robots.txt"), /Allow: \//);
});

test("every page has a canonical + EN/FR hreflang pair and is indexable", () => {
  for (const f of ["contact.html", "community.html", "privacy.html"]) {
    const t = read(f);
    assert.match(t, /rel="canonical"/);
    assert.match(t, /hreflang="en"/);
    assert.match(t, /hreflang="fr"/);
    assert.ok(!/name="robots"[^>]*noindex/i.test(t), `${f} is noindex`);
  }
});

test("no server secret leaked into the built site", () => {
  for (const f of htmlFiles().concat(readdirSync(join(OUT, "assets/generated")).map((x) => join("assets/generated", x)))) {
    const t = read(f);
    assert.ok(!/RESEND_API_KEY|ADMIN_TOKEN|POSTGRES_URL|re_[A-Za-z0-9]{20}/.test(t), f);
  }
});

// --- P1 visual / demo / nav contract -------------------------------------

test("hero uses a real screenshot, not the generative #app simulation", () => {
  const t = read("index.html");
  assert.ok(!/id="app"[\s>]/.test(t), "#app generative window still present");
  assert.match(t, /class="shot shot--hero"/);
  assert.match(t, /\/assets\/app\/screens\/dashboard-(light|dark)\.webp/);
  assert.match(t, /fetchpriority="high"/);
});

test("every product screenshot referenced by index.html exists in dist", () => {
  const t = read("index.html");
  const refs = new Set(
    [...t.matchAll(/\/assets\/app\/screens\/[A-Za-z0-9@.\-]+\.webp/g)].map((m) => m[0])
  );
  assert.ok(refs.size >= 12, `only ${refs.size} screenshot refs`);
  for (const ref of refs) assert.ok(existsSync(join(OUT, ref)), `missing ${ref}`);
});

test("product images are lazy + async + carry width/height and alt", () => {
  const t = read("index.html");
  const imgs = [...t.matchAll(/<img[^>]+\/assets\/app\/screens\/[^>]+>/g)].map((m) => m[0]);
  assert.ok(imgs.length >= 6);
  for (const img of imgs) {
    assert.match(img, /decoding="async"/, img);
    assert.match(img, /width="\d+"\s+height="\d+"/, img);
    assert.match(img, /alt="[^"]{10,}"/, img);
    // the hero image is intentionally eager (fetchpriority high); the rest lazy
    if (!/fetchpriority="high"/.test(img)) assert.match(img, /loading="lazy"/, img);
  }
});

test("light + dark <source> is provided for product screenshots", () => {
  const t = read("index.html");
  assert.ok(
    (t.match(/media="\(prefers-color-scheme: dark\)"[^>]*\/assets\/app\/screens\//g) || []).length >= 6
  );
});

test("Space Lens interactive demo is present, deterministic and non-destructive", () => {
  const t = read("index.html");
  assert.match(t, /id="space-lens"/);
  assert.match(t, /id="slMap"/);
  assert.match(t, /id="slScan"/);
  assert.match(t, /Run demo scan/);
  assert.match(t, /data-state="idle"/);
  const js = read(join("assets/generated", readdirSync(join(OUT, "assets/generated")).find((f) => /^root-\d+-.*\.js$/.test(f))));
  assert.match(js, /function spaceLens\(/);
  assert.match(t, /Deterministic demo data|no files are read/i);
  // no destructive verb anywhere in the demo section
  const section = t.slice(t.indexOf('id="space-lens"'), t.indexOf('id="findings"'));
  for (const bad of [/\bdelete\b/i, /\btrash\b/i, /\bremove\b/i, /\bclean\b/i]) {
    assert.ok(!bad.test(section), `Space Lens section contains ${bad}`);
  }
  assert.match(js, /prefers-reduced-motion|RM\.matches/);
});

test("reduced-motion styles exist for the new surfaces", () => {
  const genCss = read(join("assets/generated", readdirSync(join(OUT, "assets/generated")).find((f) => /^root-\d+-.*\.css$/.test(f))));
  assert.match(genCss, /prefers-reduced-motion:\s*reduce[^}]*\.sl-map/);
  assert.match(read("assets/shell/public.css"), /prefers-reduced-motion/);
});

// --- #findings: no generative product UI ---------------------------------

test("#findings is editorial, not a simulated app window", () => {
  const src = readFileSync(join(SITE, "index.html"), "utf8");
  const t = read("index.html");
  // section kept for its conceptual purpose
  assert.match(t, /<section id="findings">/);
  assert.match(t, /id="findings"/); // rail link target still valid
  // the simulated-window slab and its parts are gone
  for (const bad of ['class="slab"', 'class="slab-top"', 'class="slab-body"',
                     'class="slab-foot"', 'id="slabPath"', 'id="findRows"',
                     'id="findTotal"', 'id="findMeasure"', 'id="tabs"',
                     'class="fr"', 'class="pill reviewed"']) {
    assert.ok(!src.includes(bad), `#findings still ships ${bad}`);
    assert.ok(!t.includes(bad), `built page still ships ${bad}`);
  }
  // the replacement uses ordinary site typography
  const section = t.slice(t.indexOf('id="findings"'), t.indexOf('id="health"'));
  assert.match(section, /class="facts find-cats"/);
  assert.match(section, /Recoverable/);
  assert.match(section, /Reversible/);
  assert.match(section, /macOS Trash/);
});

test("no synthetic finding / recoverable-bytes generator remains", () => {
  const src = readFileSync(join(SITE, "index.html"), "utf8");
  for (const dead of ["function demo(", "function findings(", "function bubblePack(",
                      "const VIEWS =", "const FIND =", "demoState", "demoLabel",
                      "demoTimer", "demoRAF", "#slabPath", "#findRows", "#findTotal",
                      '#tabs"', "#app", "#vRows", "#vFoot", "#scanToggle", "#scanCancel",
                      '"coretend-view"']) {
    assert.ok(!src.includes(dead), `dead demo code still present: ${dead}`);
  }
  const js = read(join("assets/generated", readdirSync(join(OUT, "assets/generated"))
    .find((f) => /^root-\d+-.*\.js$/.test(f))));
  for (const dead of ["function demo(", "function findings(", "function bubblePack(",
                      "VIEWS", "demoState"]) {
    assert.ok(!js.includes(dead), `dead demo code in generated JS: ${dead}`);
  }
});

test("no dead .app/.lens/.rows/.slab/.tabs/.tag CSS rules remain", () => {
  const genCss = read(join("assets/generated", readdirSync(join(OUT, "assets/generated"))
    .find((f) => /^root-\d+-.*\.css$/.test(f))));
  for (const sel of [".app-side", ".app-main", ".app-body", ".app-foot", ".app-top",
                     ".lens b", ".rows div", ".slab-top", ".slab-foot", ".fr .nm",
                     "@keyframes rowin", "@keyframes sweepx", "@keyframes confirmation-pulse",
                     ".pill.reviewed", ".sample-label"]) {
    assert.ok(!genCss.includes(sel), `dead CSS rule still present: ${sel}`);
  }
  // shared classes that must survive
  assert.match(genCss, /\.dots\b/);
  assert.match(genCss, /\.mini\b/);
});

test("#findings keeps EN/FR parity (every string translatable)", () => {
  const src = readFileSync(join(SITE, "index.html"), "utf8");
  const section = src.slice(src.indexOf('<section id="findings">'),
                            src.indexOf("</section>", src.indexOf('id="findings"')));
  // every attribute-less <b>/<span> with prose (not a bare section number)
  // must carry data-fr — i.e. it should have an attribute
  const textEls = (section.match(/<(b|span)>[^<]+<\/(b|span)>/g) || [])
    .filter((el) => !/^<(b|span)>\s*\d+\s*<\/(b|span)>$/.test(el));
  assert.ok(textEls.length === 0, `#findings has untranslated inline text: ${textEls.join(" | ")}`);
  assert.ok((section.match(/data-fr="/g) || []).length >= 8, "expected >= 8 data-fr strings");
  // FR build actually swaps them
  const fr = read("fr-route.html");
  const frSection = fr.slice(fr.indexOf('id="findings"'), fr.indexOf('id="health"'));
  assert.match(frSection, /Récupérable/);
  assert.match(frSection, /Réversible/);
});

test("mobile navigation exists with correct ARIA on info pages", () => {
  const t = read("contact.html");
  assert.match(t, /id="navToggle"[^>]+aria-expanded="false"/);
  assert.match(t, /aria-controls="mobile-nav"/);
  assert.match(t, /<nav class="mobile-nav" id="mobile-nav"[^>]*hidden>/);
  const js = read("assets/shell/public.js");
  assert.match(js, /function mobileNav\(/);
  assert.match(js, /key === "Escape"/);
  assert.match(js, /aria-expanded/);
});

test("stale 'no built-in restore' wording is gone; 1.1 Restore Center is named", () => {
  for (const f of htmlFiles()) {
    assert.ok(!/no built-in restore|pas de fonction de restauration/i.test(read(f)), f);
  }
  assert.match(read("index.html"), /Restore Center/);
});

test("brand: vector favicon + apple-touch-icon linked, no upscaled PNG in the header mark", () => {
  const t = read("index.html");
  assert.match(t, /rel="icon" href="\/assets\/brand\/favicon(-v2-\d+)?\.(svg|png)"/);
  assert.match(t, /rel="apple-touch-icon"/);
  // header wordmark is inline <svg>, not an <img>
  const header = t.slice(t.indexOf('<header'), t.indexOf('</header>'));
  assert.ok(!/<img[^>]+>/.test(header), "header contains a raster image");
  assert.match(header, /class="mark ct-logo ct-logo--header/);
});

test("info-page JSON-LD (@graph WebPage + BreadcrumbList) parses", () => {
  for (const f of ["contact.html", "community.html", "security.html", "changelog.html", "privacy.html"]) {
    const t = read(f);
    const blocks = [...t.matchAll(/<script type="application\/ld\+json">(.*?)<\/script>/gs)].map((m) => m[1]);
    assert.ok(blocks.length >= 1, `${f} has no JSON-LD`);
    const parsed = blocks.map((b) => JSON.parse(b.replace(/<\\\//g, "</")));
    const graph = parsed.flatMap((p) => p["@graph"] || [p]);
    assert.ok(graph.some((n) => n["@type"] === "WebPage"), `${f} WebPage`);
    assert.ok(graph.some((n) => n["@type"] === "BreadcrumbList"), `${f} BreadcrumbList`);
  }
});

test("desktop info-page header is compact (2 nav links); footer carries the rest", () => {
  const t = read("security.html");
  const bar = t.slice(t.indexOf('<nav class="bar-actions"'), t.indexOf("</nav>"));
  const desktopLinks = (bar.match(/class="bar-link nav-desktop"/g) || []).length;
  assert.equal(desktopLinks, 2, "expected exactly Community + Contact in the desktop bar");
  const foot = t.slice(t.indexOf('class="foot-links"'), t.indexOf("</ul>", t.indexOf('class="foot-links"')));
  for (const href of ["/security", "/changelog", "/community", "/contact"]) {
    assert.ok(foot.includes(`href="${href}"`) || foot.includes(`href="/fr${href}"`), `footer missing ${href}`);
  }
});
