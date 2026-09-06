// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Manual website QA helper (NOT a CI gate — Scripts/site/test-site.mjs is the
// gate). Run on demand during a QA closure pass:
//
//   node Scripts/site/qa-manual.mjs
//
// It: writes representative screenshots to
// Documentation/VisualAudit/_capture_<date>_site-qa/ (gitignored); drives the
// synthetic Space Lens demo (scan -> complete -> select -> drill -> back);
// checks the Contact / Community client forms (api-form target, honeypot,
// no mailto, unchecked public-review consent, no voting UI); walks the
// keyboard (info-page hamburger open/Escape, homepage skip link / theme /
// language); and does a light SEO/best-practice DOM audit (one h1, title,
// meta description, canonical, lang, one main, viewport, img alt, no positive
// tabindex). Exits non-zero on any console error, first-party 4xx, or
// horizontal overflow. Needs a Playwright Chromium (same as test-site.mjs).
import assert from 'node:assert/strict'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { buildSite, startSite, loadPlaywright, launchChromium, repoRoot } from './site-fixture.mjs'

const SHOT = join(repoRoot, 'Documentation/VisualAudit/_capture_2026-09-06_site-qa')
await mkdir(SHOT, { recursive: true })
const b = await buildSite(); const fx = await startSite(b.output)
const { chromium } = await loadPlaywright(); const browser = await launchChromium(chromium)
const problems = []
const O = fx.origin

function watch(page, label) {
  page.on('pageerror', e => problems.push(`${label}: pageerror ${e.message}`))
  page.on('console', m => { if (m.type() === 'error' && !/status of 404/.test(m.text())) problems.push(`${label}: console ${m.text()}`) })
  page.on('response', r => {
    const u = new URL(r.url())
    if (u.origin === O && r.status() >= 400 && r.request().resourceType() !== 'document') problems.push(`${label}: ${u.pathname} ${r.status()}`)
  })
}

async function shot(ctxOpts, route, name, extra) {
  const ctx = await browser.newContext(ctxOpts); const page = await ctx.newPage(); watch(page, name)
  await page.goto(`${O}${route}`, { waitUntil: 'networkidle' })
  if (extra) await extra(page)
  await page.screenshot({ path: join(SHOT, `${name}.png`), fullPage: !ctxOpts.viewport || ctxOpts.viewport.height >= 900 })
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1)
  assert.ok(overflow, `${name}: horizontal overflow`)
  await ctx.close()
  console.log(`shot ${name}`)
}

const DESKTOP = { viewport: { width: 1440, height: 900 } }
const MOBILE = { viewport: { width: 390, height: 844 } }

// §7 representative states
await shot({ ...DESKTOP, colorScheme: 'light' }, '/en', 'home-en-light-desktop')
await shot({ ...DESKTOP, colorScheme: 'dark' }, '/fr', 'home-fr-dark-desktop')
await shot({ ...MOBILE }, '/en', 'home-en-mobile')
await shot({ ...DESKTOP }, '/en', 'findings-editorial', p => p.locator('#findings').scrollIntoViewIfNeeded())
await shot({ ...DESKTOP }, '/contact', 'contact', p => p.locator('.ct-form').first().scrollIntoViewIfNeeded())
await shot({ ...DESKTOP }, '/community', 'community')
await shot({ ...DESKTOP }, '/changelog', 'changelog')

// §7 download resolver — 302 to a real DMG per channel
{
  const releases = JSON.parse(await readFile(new URL('../../Website/api/_lib/releases.json', import.meta.url), 'utf8'))
  const want = q => (/channel=beta/.test(q) && releases.beta?.dmgURL) || releases.stable.dmgURL
  for (const q of ['', '?channel=stable', '?channel=beta']) {
    const r = await fetch(`${O}/download${q}`, { redirect: 'manual' })
    assert.equal(r.status, 302, `/download${q} status`)
    const loc = r.headers.get('location') || ''
    assert.match(loc, /^https:\/\/github\.com\/.+\.dmg$/, `/download${q} target`)
    assert.equal(loc, want(q), `/download${q} resolved to the wrong channel`)
  }
  console.log(`download: /download -> stable, ?channel=beta -> ${releases.beta ? releases.beta.version : 'stable (no beta)'} DMG, all 302`)
}

// §13 Space Lens demo interaction (deterministic, synthetic)
{
  const ctx = await browser.newContext({ ...DESKTOP, reducedMotion: 'no-preference' })
  const page = await ctx.newPage(); watch(page, 'spacelens')
  await page.goto(`${O}/en`, { waitUntil: 'domcontentloaded' })
  await page.locator('#slDemo').scrollIntoViewIfNeeded()
  assert.equal(await page.locator('#slDemo').getAttribute('data-state'), 'idle')
  await page.locator('#slScan').click()
  await page.waitForFunction(() => document.querySelector('#slDemo')?.getAttribute('data-state') === 'complete', null, { timeout: 8000 })
  const circles = await page.locator('#slMap circle').count()
  const rows = await page.locator('#slList li').count()
  assert.ok(circles > 0 && rows > 0, 'space lens produced no bubbles/rows')
  await page.locator('#slList li').first().click()
  const selById = await page.locator('#slList li.is-selected').count()
  assert.equal(selById, 1, 'list selection not reflected')
  await page.locator('#slList li').first().dblclick()
  await page.waitForFunction(() => !document.querySelector('#slBack')?.hidden, null, { timeout: 3000 })
  const crumbTxt = (await page.locator('#slCrumbs').innerText()).trim()
  assert.ok(crumbTxt.length > 0, 'breadcrumb empty after drill')
  await page.locator('#slBack').click()
  await page.screenshot({ path: join(SHOT, 'spacelens-demo-complete.png') })
  // never implies filesystem access
  const demoText = await page.locator('#space-lens').innerText()
  assert.ok(/demo|no files are read|synthetic|démonstration|aucun/i.test(demoText), 'demo not labelled synthetic')
  console.log(`spacelens: ${circles} bubbles, ${rows} rows, drill+back+breadcrumb OK`)
  await ctx.close()
}

// §14 Contact form client behaviour (no prod credentials)
{
  const ctx = await browser.newContext({ ...DESKTOP })
  const page = await ctx.newPage(); watch(page, 'contact-form')
  await page.goto(`${O}/contact`, { waitUntil: 'networkidle' })
  const form = page.locator('[data-api-form="/api/contact"]').first()
  assert.equal(await form.count(), 1, 'no contact api-form')
  assert.equal(await page.locator('input[name="company"]').count(), 1, 'no honeypot field')
  assert.ok(!(await page.content()).includes('href="mailto:'), 'mailto fallback present')
  // required-field validation without sending
  const submit = form.locator('button[type="submit"], [type="submit"]').first()
  await submit.click().catch(() => {})
  const invalid = await page.evaluate(() => document.querySelectorAll('form :invalid').length)
  assert.ok(invalid >= 1, 'no client validation on empty submit')
  console.log('contact form: api-form + honeypot + no-mailto + client validation OK')
  await ctx.close()
}
// §14 Community
{
  const ctx = await browser.newContext({ ...DESKTOP })
  const page = await ctx.newPage(); watch(page, 'community-form')
  await page.goto(`${O}/community`, { waitUntil: 'networkidle' })
  assert.equal(await page.locator('#community-feed').count(), 1, 'no community feed')
  assert.equal(await page.locator('[data-api-form="/api/community"]').count(), 1, 'no community api-form')
  assert.equal(await page.locator('input[name="website"]').count(), 1, 'no community honeypot')
  const consent = page.locator('input[type="checkbox"]').first()
  assert.equal(await consent.isChecked(), false, 'public-review consent pre-checked')
  assert.equal(await page.locator('[aria-label*="vote" i], .vote, [data-vote]').count(), 0, 'voting UI present in beta')
  console.log('community: feed + api-form + unchecked consent + no voting OK')
  await ctx.close()
}

// §9 keyboard walk — info-page mobile nav (hamburger), + homepage rail/theme/lang
{
  // Info page: mobile nav toggle is keyboard-operable, Escape closes it,
  // focus is not lost behind the overlay.
  const ctx = await browser.newContext({ ...MOBILE })
  const page = await ctx.newPage(); watch(page, 'keyboard-info')
  await page.goto(`${O}/contact`, { waitUntil: 'networkidle' })
  await page.keyboard.press('Tab')
  const first = await page.evaluate(() => document.activeElement?.className || document.activeElement?.tagName)
  assert.ok(/skip/i.test(String(first)), `first Tab focus is ${first}, expected skip link`)
  const toggle = page.locator('#navToggle')
  await toggle.focus(); await page.keyboard.press('Enter')
  assert.equal(await toggle.getAttribute('aria-expanded'), 'true', 'mobile nav did not open via keyboard')
  assert.ok(await page.locator('#mobile-nav a, #mobile-nav button').count() > 0, 'mobile nav has no focusable items')
  await page.keyboard.press('Escape')
  assert.equal(await toggle.getAttribute('aria-expanded'), 'false', 'Escape did not close mobile nav')
  assert.ok(await page.evaluate(() => document.activeElement && document.activeElement !== document.body), 'focus lost after closing overlay')
  console.log('keyboard (info): skip-link, mobile nav Enter-open / Escape-close, focus retained OK')
  await ctx.close()
}
{
  // Homepage: skip link, theme control and language links are keyboard-reachable
  // and operable; the scroll rail links move focus into the page.
  const ctx = await browser.newContext({ ...DESKTOP })
  const page = await ctx.newPage(); watch(page, 'keyboard-home')
  await page.goto(`${O}/en`, { waitUntil: 'networkidle' })
  await page.keyboard.press('Tab')
  assert.ok(/skip/i.test(String(await page.evaluate(() => document.activeElement?.className || ''))), 'homepage first Tab is not the skip link')
  // theme + language controls are keyboard-reachable (not tabindex=-1) and
  // named. (Theme state-change is covered by the "system/manual theme" gate.)
  for (const sel of ['#theme', '[data-lang-link="fr"]']) {
    const el = page.locator(sel)
    await el.focus()
    assert.ok(await el.evaluate(e => e === document.activeElement), `${sel} not focusable`)
    assert.ok(await el.evaluate(e => (e.getAttribute('aria-label') || e.textContent || '').trim().length > 0), `${sel} has no accessible name`)
    assert.ok(await el.evaluate(e => (e.getAttribute('tabindex') ?? '0') !== '-1'), `${sel} is tabindex=-1`)
  }
  await page.locator('[data-lang-link="fr"]').focus()
  await page.keyboard.press('Enter')
  await page.waitForURL(/\/fr/, { timeout: 4000 })
  console.log('keyboard (home): skip-link + theme/language controls focusable & named; Enter on lang link navigates OK')
  await ctx.close()
}

// light SEO/best-practice DOM audit (no Lighthouse)
{
  for (const r of ['/en', '/fr', '/contact', '/community', '/changelog']) {
    const ctx = await browser.newContext({ ...DESKTOP }); const page = await ctx.newPage(); watch(page, `seo${r}`)
    await page.goto(`${O}${r}`, { waitUntil: 'networkidle' })
    const a = await page.evaluate(() => ({
      h1: document.querySelectorAll('h1').length,
      title: document.title.length,
      desc: document.querySelector('meta[name="description"]')?.content?.length || 0,
      canonical: !!document.querySelector('link[rel="canonical"]'),
      lang: document.documentElement.lang,
      main: document.querySelectorAll('main').length,
      viewport: !!document.querySelector('meta[name="viewport"]'),
      imgNoAlt: [...document.querySelectorAll('img')].filter(i => !i.hasAttribute('alt')).length,
      posTab: [...document.querySelectorAll('[tabindex]')].filter(e => Number(e.getAttribute('tabindex')) > 0).length,
    }))
    assert.equal(a.h1, 1, `${r}: ${a.h1} <h1>`)
    assert.ok(a.title > 10 && a.title < 70, `${r}: title length ${a.title}`)
    assert.ok(a.desc > 40, `${r}: meta description ${a.desc}`)
    assert.ok(a.canonical, `${r}: no canonical`)
    assert.ok(/^(en|fr)/.test(a.lang), `${r}: lang ${a.lang}`)
    assert.equal(a.main, 1, `${r}: ${a.main} <main>`)
    assert.ok(a.viewport, `${r}: no viewport meta`)
    assert.equal(a.imgNoAlt, 0, `${r}: ${a.imgNoAlt} <img> without alt`)
    assert.equal(a.posTab, 0, `${r}: ${a.posTab} positive tabindex`)
    await ctx.close()
    console.log(`seo ${r}: h1/title/desc/canonical/lang/main/viewport/alt/tabindex OK`)
  }
}

await browser.close(); await fx.close()
await writeFile(join(SHOT, 'NOTES.txt'), `Website QA screenshots — 2026-09-06\nGenerated by Scripts/site/.qa-run.mjs (not a committed gate).\nSynthetic/demo data only. Gitignored (VisualAudit/_capture_*).\nproblems: ${problems.length ? JSON.stringify(problems, null, 1) : 'none'}\n`)
console.log(problems.length ? `\nPROBLEMS:\n${problems.join('\n')}` : '\nALL CLEAN — no console errors, no 4xx first-party, no overflow')
process.exit(problems.length ? 1 : 0)
