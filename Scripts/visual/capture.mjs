#!/usr/bin/env node
/**
 * Deterministic visual regression for CoreTend's generated clean routes.
 *
 * `--update` is the only mode which writes reference.json. The default mode
 * compares fingerprints and writes reviewable PNGs only for differences.
 * `--capture-only` writes the current PNG set without accepting it as truth.
 */
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import {
  buildSite,
  launchChromium,
  loadPlaywright,
  repoRoot,
  startSite,
} from '../site/site-fixture.mjs'

const here = dirname(fileURLToPath(import.meta.url))
const refFile = join(here, 'reference.json')
const outDir = join(here, 'output')
const update = process.argv.includes('--update')
const captureOnly = process.argv.includes('--capture-only')
if (update && captureOnly) throw new Error('choose either --update or --capture-only')

const VIEWPORTS = [
  { name: '1440x900', width: 1440, height: 900 },
  { name: '1280x800', width: 1280, height: 800 },
  { name: '1024x768', width: 1024, height: 768 },
  { name: '820x1180', width: 820, height: 1180 },
  { name: '430x932', width: 430, height: 932 },
  { name: '390x844', width: 390, height: 844 },
  { name: '360x800', width: 360, height: 800 },
]

const DESKTOP = VIEWPORTS[0]
const MOBILE = VIEWPORTS[4]
const ROUTE_MATRIX = VIEWPORTS.flatMap(viewport => [
  { name: `home-en-light--${viewport.name}`, path: '/en/', viewport, language: 'en', theme: 'light' },
  { name: `home-fr-light--${viewport.name}`, path: '/fr/', viewport, language: 'fr', theme: 'light' },
  { name: `home-en-dark--${viewport.name}`, path: '/en/', viewport, language: 'en', theme: 'dark' },
  { name: `home-fr-dark--${viewport.name}`, path: '/fr/', viewport, language: 'fr', theme: 'dark' },
])

const SUPPORTING_PAGES = [DESKTOP, MOBILE].flatMap(viewport => [
  { name: `root-no-js--${viewport.name}`, path: '/', viewport, theme: 'light', javaScriptEnabled: false },
  { name: `privacy--${viewport.name}`, path: '/privacy', viewport, theme: 'light', javaScriptEnabled: false },
  { name: `support--${viewport.name}`, path: '/support', viewport, theme: 'light', javaScriptEnabled: false },
  { name: `legal--${viewport.name}`, path: '/legal', viewport, theme: 'light', javaScriptEnabled: false },
  { name: `licenses--${viewport.name}`, path: '/licenses', viewport, theme: 'light', javaScriptEnabled: false },
  { name: `not-found--${viewport.name}`, path: '/visual-not-found', viewport, theme: 'light', javaScriptEnabled: false },
])

const GRID = 32
const CELL_TOLERANCE = 6
const MAX_CHANGED_CELLS = 4
const FREEZE = `
  *, *::before, *::after {
    animation-play-state: paused !important;
    transition-duration: 0s !important;
    transition-delay: 0s !important;
    caret-color: transparent !important;
  }
  [data-reveal] { opacity: 1 !important; transform: none !important; clip-path: none !important; }
  video, #field, #grain, #spot { visibility: hidden !important; }
`

async function loadPNG() {
  try { return (await import('pngjs')).PNG } catch (primaryError) {
    const configured = process.env.CORETEND_NODE_MODULES
    if (configured) {
      try {
        const module = await import(pathToFileURL(join(configured, 'pngjs', 'lib', 'png.js')).href)
        return module.PNG ?? module.default?.PNG ?? module.default
      } catch {}
    }
    throw new Error(`pngjs is required. Run "npm install --no-save pngjs". (${primaryError.message})`)
  }
}

function fingerprint(png) {
  const { width, height, data } = png
  const cells = []
  for (let gy = 0; gy < GRID; gy++) {
    for (let gx = 0; gx < GRID; gx++) {
      const x0 = Math.floor((gx * width) / GRID)
      const x1 = Math.max(x0 + 1, Math.floor(((gx + 1) * width) / GRID))
      const y0 = Math.floor((gy * height) / GRID)
      const y1 = Math.max(y0 + 1, Math.floor(((gy + 1) * height) / GRID))
      let sum = 0
      let count = 0
      for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
          const index = (width * y + x) << 2
          sum += 0.2126 * data[index] + 0.7152 * data[index + 1] + 0.0722 * data[index + 2]
          count++
        }
      }
      cells.push(Math.round(sum / count))
    }
  }
  return cells
}

function compare(label, record, references, failures) {
  const reference = references[label]
  if (!reference) {
    failures.push(`${label}: no reference (review captures, then run --update deliberately)`)
    return false
  }
  if (reference.width !== record.width || reference.height !== record.height) {
    failures.push(`${label}: size changed ${reference.width}x${reference.height} -> ${record.width}x${record.height}`)
    return false
  }
  let changed = 0
  let worst = 0
  for (let index = 0; index < record.cells.length; index++) {
    const delta = Math.abs(record.cells[index] - reference.cells[index])
    if (delta > CELL_TOLERANCE) changed++
    worst = Math.max(worst, delta)
  }
  if (changed > MAX_CHANGED_CELLS) {
    failures.push(`${label}: ${changed}/${GRID * GRID} cells changed (max delta ${worst})`)
    return false
  }
  return true
}

async function freeze(page) {
  await page.addStyleTag({ content: FREEZE })
  await page.evaluate(async () => {
    await document.fonts.ready
    for (const animation of document.getAnimations({ subtree: true })) animation.pause()
  })
}

async function prepareOrbit(page, selector, times = [4250, 6600, 8750]) {
  await page.locator(selector).evaluate((logo, requestedTimes) => {
    logo.classList.remove('is-initializing')
    const animations = logo._ctOrbit?.animations ?? []
    animations.forEach(({ animation }, index) => {
      animation.currentTime = requestedTimes[index]
      animation.pause()
    })
  }, times)
}

async function capturePage(browser, base, target) {
  const context = await browser.newContext({
    bypassCSP: true,
    viewport: { width: target.viewport.width, height: target.viewport.height },
    deviceScaleFactor: 1,
    reducedMotion: 'reduce',
    colorScheme: target.theme,
    locale: target.language === 'fr' ? 'fr-FR' : 'en-US',
    javaScriptEnabled: target.javaScriptEnabled ?? true,
  })
  const page = await context.newPage()
  const response = await page.goto(base + target.path, { waitUntil: 'networkidle' })
  if (!response || (![200, 404].includes(response.status()))) {
    throw new Error(`${target.path} returned ${response?.status() ?? 'no response'}`)
  }
  if (target.javaScriptEnabled !== false) await freeze(page)
  else await page.evaluate(() => document.fonts.ready)
  await page.waitForTimeout(80)
  const shot = await page.screenshot()
  await context.close()
  return shot
}

async function stateCaptures(browser, base) {
  const captures = []
  async function state(name, options, prepare, selector) {
    const context = await browser.newContext({
      bypassCSP: true,
      viewport: { width: options.viewport.width, height: options.viewport.height },
      deviceScaleFactor: 1,
      reducedMotion: options.reducedMotion ?? 'no-preference',
      colorScheme: options.theme ?? 'light',
      locale: 'en-US',
    })
    const page = await context.newPage()
    await page.goto(`${base}/en/`, { waitUntil: 'domcontentloaded' })
    await page.evaluate(() => document.fonts.ready)
    if (prepare) await prepare(page)
    await page.addStyleTag({ content: 'video, #field, #grain, #spot { visibility:hidden !important }' })
    const shot = selector ? await page.locator(selector).screenshot() : await page.screenshot()
    captures.push({ name, shot })
    await context.close()
  }

  await state('logo-official-static', { viewport: DESKTOP, reducedMotion: 'reduce' }, null, '.ct-logo--hero')
  await state('logo-initialization', { viewport: DESKTOP }, async page => {
    await page.locator('.ct-logo--hero').evaluate(logo => {
      for (const animation of logo.getAnimations({ subtree: true })) {
        animation.currentTime = 520
        animation.pause()
      }
    })
  }, '.ct-logo--hero')
  await state('logo-orbits-active', { viewport: DESKTOP }, page => prepareOrbit(page, '.ct-logo--hero'), '.ct-logo--hero')
  await state('logo-hover', { viewport: DESKTOP }, async page => {
    await page.locator('.hero-mark').hover()
    await page.waitForTimeout(340)
    await prepareOrbit(page, '.ct-logo--hero', [5600, 8100, 10200])
  }, '.ct-logo--hero')
  await state('logo-focus', { viewport: DESKTOP }, async page => {
    await page.locator('.bar .wordmark').focus()
    await page.waitForTimeout(340)
    await prepareOrbit(page, '.ct-logo--header', [5600, 8100, 10200])
  }, '.bar .wordmark')
  await state('header-compact', { viewport: DESKTOP }, async page => {
    await page.evaluate(() => scrollTo(0, 220))
    await page.waitForTimeout(120)
    await prepareOrbit(page, '.ct-logo--header')
    await freeze(page)
  }, '#bar')
  await state('footer-stabilized', { viewport: DESKTOP }, async page => {
    await page.evaluate(() => scrollTo(0, document.body.scrollHeight))
    await page.waitForTimeout(1350)
    await freeze(page)
  }, 'footer')
  await state('simulation-scanning', { viewport: DESKTOP }, async page => {
    await page.locator('[data-view="storage"]').click()
    await page.waitForFunction(() => parseFloat(document.querySelector('#vTrack')?.style.width) >= 15)
    await freeze(page)
  }, '#app')
  await state('simulation-paused', { viewport: DESKTOP }, async page => {
    await page.locator('[data-view="storage"]').click()
    await page.waitForFunction(() => parseFloat(document.querySelector('#vTrack')?.style.width) >= 15)
    await page.locator('#scanToggle').click()
    await freeze(page)
  }, '#app')
  await state('simulation-complete', { viewport: DESKTOP, reducedMotion: 'reduce' }, page => freeze(page), '#app')
  await state('mobile-reduced', { viewport: MOBILE, reducedMotion: 'reduce', theme: 'dark' }, page => freeze(page), null)
  return captures
}

const build = process.env.VISUAL_BASE_URL ? null : await buildSite()
const fixture = build ? await startSite(build.output) : null
const base = process.env.VISUAL_BASE_URL?.replace(/\/$/, '') ?? fixture.origin
const { chromium } = await loadPlaywright()
const PNG = await loadPNG()
const browser = await launchChromium(chromium)
await mkdir(outDir, { recursive: true })
const references = existsSync(refFile) ? JSON.parse(await readFile(refFile, 'utf8')) : {}
const next = {}
const failures = []

async function record(label, shot, alwaysWrite = false) {
  const png = PNG.sync.read(shot)
  const value = { width: png.width, height: png.height, cells: fingerprint(png) }
  next[label] = value
  const matches = update || captureOnly ? true : compare(label, value, references, failures)
  if (alwaysWrite || captureOnly || !matches) await writeFile(join(outDir, `${label}.png`), shot)
}

try {
  for (const target of [...ROUTE_MATRIX, ...SUPPORTING_PAGES]) {
    await record(target.name, await capturePage(browser, base, target))
  }
  for (const target of await stateCaptures(browser, base)) await record(target.name, target.shot, true)
} finally {
  await browser.close()
  await fixture?.close()
  await build?.cleanup()
}

if (update) {
  await writeFile(refFile, `${JSON.stringify(next, null, 1)}\n`)
  console.log(`Wrote ${Object.keys(next).length} deliberate reference fingerprints.`)
  console.log('Review both the JSON diff and state PNGs before committing.')
} else if (captureOnly) {
  console.log(`Captured ${Object.keys(next).length} review PNGs without changing reference.json.`)
} else if (failures.length) {
  console.error(`FAIL — ${failures.length} visual difference(s):`)
  failures.forEach(failure => console.error(`  - ${failure}`))
  console.error('Actual differences and signature-state captures are in Scripts/visual/output/.')
  process.exitCode = 1
} else {
  console.log(`PASS — ${Object.keys(next).length} captures match their reviewed fingerprints.`)
}
