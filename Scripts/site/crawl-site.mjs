#!/usr/bin/env node
/** Crawl canonical CoreTend pages and reject broken or technical public URLs. */
import assert from 'node:assert/strict'
import { readdir, readFile } from 'node:fs/promises'
import { extname, join, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildSite, launchChromium, loadPlaywright, startSite } from './site-fixture.mjs'

export const CANONICAL_ROUTES = ['/', '/en/', '/fr/', '/privacy', '/support', '/legal', '/licenses']
const TEXT_EXTENSIONS = new Set(['.css', '.html', '.js', '.json', '.svg', '.txt', '.vtt', '.webmanifest', '.xml'])
const TECHNICAL_URL = /(?:\.html(?:[?#/"'\s<)]|$)|\/(?:site|Website|public|dist|out)(?:\/|$)|localhost|127\.0\.0\.1|\/Users\/(?!demo(?:\/|\b)))/i
const HISTORICAL_BRAND_COLOR = /#(?:13674a|5c54cc|a8e6c1|9b8afb)\b/i

async function filesBelow(directory) {
  const result = []
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) result.push(...await filesBelow(path))
    else if (entry.isFile()) result.push(path)
  }
  return result
}

export async function scanPublicOutput(buildDirectory) {
  const failures = []
  const files = await filesBelow(buildDirectory)
  for (const file of files) {
    if (!TEXT_EXTENSIONS.has(extname(file))) continue
    const content = await readFile(file, 'utf8')
    const match = content.match(TECHNICAL_URL)
    if (match) {
      failures.push(`${file.slice(buildDirectory.length + 1)} exposes forbidden text ${JSON.stringify(match[0])}`)
    }
    const legacyColor = content.match(HISTORICAL_BRAND_COLOR)
    if (legacyColor) {
      failures.push(`${file.slice(buildDirectory.length + 1)} exposes historical brand color ${legacyColor[0]}`)
    }
  }

  const sitemap = await readFile(join(buildDirectory, 'sitemap.xml'), 'utf8')
  const sitemapLocations = [...sitemap.matchAll(/<loc>(.*?)<\/loc>/g)].map(match => match[1])
  assert.deepEqual(
    sitemapLocations,
    CANONICAL_ROUTES.map(route => `https://coretend.ahmetbsbnr.com${route}`),
    'sitemap must contain only canonical public routes'
  )
  assert(!TECHNICAL_URL.test(sitemap), 'sitemap contains a technical URL')

  const robots = await readFile(join(buildDirectory, 'robots.txt'), 'utf8')
  assert.match(robots, /^User-agent: \*$/m)
  assert.match(robots, /^Sitemap: https:\/\/coretend\.ahmetbsbnr\.com\/sitemap\.xml$/m)
  assert(!TECHNICAL_URL.test(robots), 'robots.txt contains a technical URL')

  if (failures.length) throw new Error(`public-output scan failed:\n- ${failures.join('\n- ')}`)
  return { files: files.length, textFiles: files.filter(file => TEXT_EXTENSIONS.has(extname(file))).length }
}

export async function crawlSite({ browser, origin }) {
  const context = await browser.newContext({
    colorScheme: 'light',
    locale: 'en-US',
    reducedMotion: 'reduce',
    viewport: { width: 1280, height: 800 },
  })
  const page = await context.newPage()
  const failures = []
  const checked = new Map()
  const crawled = []

  async function checkInternal(raw, sourceRoute) {
    if (raw.startsWith('#')) return
    const target = new URL(raw, `${origin}${sourceRoute}`)
    if (target.origin !== origin) return
    target.hash = ''
    const key = target.href
    if (checked.has(key)) return checked.get(key)
    const request = context.request.get(key, { maxRedirects: 0 }).then(async response => {
      const status = response.status()
      const location = response.headers().location ?? ''
      if (target.pathname === '/download') {
        if (![301, 302, 303, 307, 308].includes(status) || !location.startsWith('https://github.com/')) {
          failures.push(`${sourceRoute}: /download did not redirect directly to the HTTPS GitHub release (${status} ${location})`)
        }
      } else if (status >= 400) {
        failures.push(`${sourceRoute}: ${target.pathname} returned ${status}`)
      } else if ([301, 302, 303, 307, 308].includes(status)) {
        failures.push(`${sourceRoute}: canonical internal link ${target.pathname} redirects (${status})`)
      }
      return status
    })
    checked.set(key, request)
    return request
  }

  for (const route of CANONICAL_ROUTES) {
    const response = await page.goto(`${origin}${route}`, { waitUntil: 'networkidle' })
    if (!response || response.status() !== 200) {
      failures.push(`${route}: navigation returned ${response?.status() ?? 'no response'}`)
      continue
    }
    crawled.push(route)
    const documentState = await page.evaluate(() => ({
      css: [...document.styleSheets].filter(sheet => !sheet.disabled).length,
      fontFamily: getComputedStyle(document.body).fontFamily,
      links: [...document.querySelectorAll('[href], [src], [srcset]')].flatMap(element => {
        const values = []
        for (const attribute of ['href', 'src']) {
          const value = element.getAttribute(attribute)
          if (value) values.push({ attribute, value })
        }
        const srcset = element.getAttribute('srcset')
        if (srcset) {
          for (const candidate of srcset.split(',')) {
            const value = candidate.trim().split(/\s+/)[0]
            if (value) values.push({ attribute: 'srcset', value })
          }
        }
        return values
      }),
    }))
    if (!documentState.css || /Times New Roman/i.test(documentState.fontFamily)) {
      failures.push(`${route}: page appears unstyled`)
    }

    for (const { attribute, value } of documentState.links) {
      if (/^(?:data:|mailto:|tel:)/i.test(value)) continue
      if (TECHNICAL_URL.test(value)) failures.push(`${route}: ${attribute} exposes forbidden URL ${value}`)
      if (value === '#') failures.push(`${route}: empty fragment link`)
      if (/^http:\/\//i.test(value)) failures.push(`${route}: insecure external URL ${value}`)

      if (value.startsWith('#')) {
        const found = await page.locator(value).count().catch(() => 0)
        if (!found) failures.push(`${route}: missing fragment target ${value}`)
      } else {
        await checkInternal(value, route)
      }
    }
  }
  await Promise.all(checked.values())
  await context.close()

  if (failures.length) throw new Error(`site crawl failed:\n- ${[...new Set(failures)].join('\n- ')}`)
  return { routes: crawled, internalResources: checked.size }
}

async function commandLine() {
  const externalOrigin = process.env.SITE_BASE_URL?.replace(/\/$/, '')
  const build = externalOrigin ? null : await buildSite()
  const fixture = externalOrigin ? null : await startSite(build.output)
  const origin = externalOrigin ?? fixture.origin
  const { chromium } = await loadPlaywright()
  const browser = await launchChromium(chromium)
  try {
    const output = build ? await scanPublicOutput(build.output) : null
    const crawl = await crawlSite({ browser, origin })
    console.log(`PASS — crawled ${crawl.routes.length} canonical routes and ${crawl.internalResources} internal resources.`)
    if (output) console.log(`PASS — scanned ${output.files} public files (${output.textFiles} text files).`)
  } finally {
    await browser.close()
    await fixture?.close()
    await build?.cleanup()
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await commandLine()
}
