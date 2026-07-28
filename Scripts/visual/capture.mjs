#!/usr/bin/env node
/**
 * Visual regression for the CoreTend site.
 *
 * Two modes:
 *   --update    rewrite the reference fingerprints (a deliberate human act)
 *   (default)   capture again and compare
 *
 * Why fingerprints rather than committed PNGs:
 *
 * The obvious design — commit a reference screenshot per page per viewport —
 * was built first and produced 30 MB of PNGs for 72 captures (63 MB when they
 * were full-page). That stalls pushes, bloats history forever, and nobody can
 * actually review 72 screenshots in a diff. So the repository stores a compact
 * fingerprint of each capture instead: exact pixel dimensions plus a 32x32
 * grid of average luminance. That is enough to catch the changes this suite
 * exists to catch — a moved logo, a reflowed hero, a changed grid — while
 * staying a few kilobytes of reviewable JSON.
 *
 * When a comparison fails, the actual PNG is written to Scripts/visual/output/
 * so a human can look at the real thing. The pixels are not thrown away, they
 * are just not kept in git.
 *
 * References are never refreshed automatically on failure: a visual test that
 * rewrites its own baseline whenever it fails only proves the code ran.
 *
 * Animation is frozen during capture (reduced-motion, zeroed durations, hidden
 * video), so a difference means a layout or paint change, never a frame caught
 * mid-transition. Captures are viewport-sized: composition and hierarchy live
 * above the fold, and below-the-fold layout is covered by the overflow and
 * geometry assertions in the other gates.
 */
import { chromium } from 'playwright'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { PNG } from 'pngjs'

const here = dirname(fileURLToPath(import.meta.url))
const refFile = join(here, 'reference.json')
const outDir = join(here, 'output')
const update = process.argv.includes('--update')
const base = process.env.VISUAL_BASE_URL ?? 'http://localhost:8788'

const VIEWPORTS = [
  { name: '320x568', width: 320, height: 568 },
  { name: '375x812', width: 375, height: 812 },
  { name: '390x844', width: 390, height: 844 },
  { name: '430x932', width: 430, height: 932 },
  { name: '768x1024', width: 768, height: 1024 },
  { name: '1024x768', width: 1024, height: 768 },
  { name: '1280x800', width: 1280, height: 800 },
  { name: '1440x900', width: 1440, height: 900 },
  { name: '1728x1117', width: 1728, height: 1117 },
]

const PAGES = [
  { name: 'home-en', path: '/en/index.html' },
  { name: 'home-fr', path: '/fr/index.html' },
  { name: 'verify-en', path: '/en/verify.html' },
  { name: 'verify-fr', path: '/fr/verify.html' },
  { name: 'download-en', path: '/en/download.html' },
  { name: 'demos-en', path: '/en/demos.html' },
  { name: 'install-en', path: '/en/install.html' },
  { name: 'notfound-en', path: '/en/404.html' },
]

const GRID = 32
/** Luminance units (0-255) a cell may drift before it counts as changed. */
const CELL_TOLERANCE = 6
/** Cells that may differ before the capture is called a regression. */
const MAX_CHANGED_CELLS = 4

const FREEZE = `
  *, *::before, *::after {
    animation-duration: 0s !important;
    animation-delay: 0s !important;
    transition-duration: 0s !important;
    transition-delay: 0s !important;
    caret-color: transparent !important;
  }
  [data-reveal] { opacity: 1 !important; transform: none !important; }
  video { visibility: hidden !important; }
`

/** Average luminance over a GRID x GRID grid. Tolerant of antialiasing,
 *  sensitive to anything that actually moves. */
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
      let n = 0
      for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
          const i = (width * y + x) << 2
          sum += 0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]
          n++
        }
      }
      cells.push(Math.round(sum / n))
    }
  }
  return cells
}

await mkdir(outDir, { recursive: true })
const references = existsSync(refFile) ? JSON.parse(await readFile(refFile, 'utf8')) : {}
const next = {}
const failures = []

const browser = await chromium.launch()
for (const vp of VIEWPORTS) {
  const context = await browser.newContext({
    viewport: { width: vp.width, height: vp.height },
    deviceScaleFactor: 1,
    reducedMotion: 'reduce',
    colorScheme: 'light',
  })
  const page = await context.newPage()
  for (const target of PAGES) {
    const label = `${target.name}--${vp.name}`
    await page.goto(base + target.path, { waitUntil: 'networkidle' })
    await page.addStyleTag({ content: FREEZE })
    await page.evaluate(() => document.fonts.ready)
    await page.waitForTimeout(150)

    const shot = await page.screenshot()
    const png = PNG.sync.read(shot)
    const record = { width: png.width, height: png.height, cells: fingerprint(png) }
    next[label] = record

    if (update) continue

    const ref = references[label]
    if (!ref) {
      failures.push(`${label}: no reference (run with --update)`)
      continue
    }
    if (ref.width !== record.width || ref.height !== record.height) {
      await writeFile(join(outDir, `${label}.actual.png`), shot)
      failures.push(
        `${label}: size changed ${ref.width}x${ref.height} -> ${record.width}x${record.height}`
      )
      continue
    }
    let changed = 0
    let worst = 0
    for (let i = 0; i < record.cells.length; i++) {
      const delta = Math.abs(record.cells[i] - ref.cells[i])
      if (delta > CELL_TOLERANCE) changed++
      worst = Math.max(worst, delta)
    }
    if (changed > MAX_CHANGED_CELLS) {
      await writeFile(join(outDir, `${label}.actual.png`), shot)
      failures.push(`${label}: ${changed}/${GRID * GRID} cells changed (max delta ${worst})`)
    }
  }
  await context.close()
}
await browser.close()

if (update) {
  await writeFile(refFile, `${JSON.stringify(next, null, 1)}\n`)
  const count = Object.keys(next).length
  console.log(`Wrote ${count} reference fingerprints to Scripts/visual/reference.json.`)
  console.log('Review the diff before committing: it becomes the definition of "correct".')
  process.exit(0)
}

if (failures.length) {
  console.error(`FAIL — ${failures.length} visual difference(s):`)
  for (const f of failures) console.error(`  - ${f}`)
  console.error('\nActual captures written to Scripts/visual/output/ — look at them.')
  console.error('If the change is intended, re-run with --update and commit the new references.')
  process.exit(1)
}

console.log(`PASS — ${Object.keys(next).length} captures match their references.`)
