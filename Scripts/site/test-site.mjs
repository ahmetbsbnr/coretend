#!/usr/bin/env node
/**
 * End-to-end delivery gate for CoreTend's generated public site.
 *
 * Default: build Website/build.py into a fresh temporary directory and serve
 * it through the route-aware fixture. Set SITE_BASE_URL to exercise a preview
 * or production deployment while still validating a fresh local build.
 */
import assert from 'node:assert/strict'
import { readFile, readdir } from 'node:fs/promises'
import { join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { buildSite, launchChromium, loadPlaywright, repoRoot, startSite } from './site-fixture.mjs'
import { CANONICAL_ROUTES, crawlSite, scanPublicOutput } from './crawl-site.mjs'

const VIEWPORTS = [
  { width: 1440, height: 900 },
  { width: 1280, height: 800 },
  { width: 1024, height: 768 },
  { width: 820, height: 1180 },
  { width: 430, height: 932 },
  { width: 390, height: 844 },
  { width: 360, height: 800 },
]

const EXPECTED_CANONICAL = {
  '/': 'https://coretend.ahmetbsbnr.com/',
  '/en': 'https://coretend.ahmetbsbnr.com/en',
  '/fr': 'https://coretend.ahmetbsbnr.com/fr',
  '/privacy': 'https://coretend.ahmetbsbnr.com/privacy',
  '/support': 'https://coretend.ahmetbsbnr.com/support',
  '/legal': 'https://coretend.ahmetbsbnr.com/legal',
  '/licenses': 'https://coretend.ahmetbsbnr.com/licenses',
  '/fr/privacy': 'https://coretend.ahmetbsbnr.com/fr/privacy',
  '/fr/support': 'https://coretend.ahmetbsbnr.com/fr/support',
  '/fr/legal': 'https://coretend.ahmetbsbnr.com/fr/legal',
  '/fr/licenses': 'https://coretend.ahmetbsbnr.com/fr/licenses',
}

const REDIRECTS = {
  '/index.html': '/',
  '/en/index.html': '/en',
  '/fr/index.html': '/fr',
  '/privacy.html': '/privacy',
  '/support.html': '/support',
  '/legal.html': '/legal',
  '/licenses.html': '/licenses',
  '/fr/privacy.html': '/fr/privacy',
  '/fr/support.html': '/fr/support',
  '/fr/legal.html': '/fr/legal',
  '/fr/licenses.html': '/fr/licenses',
  '/site': '/',
  '/site/index.html': '/',
  '/Website': '/',
  '/Website/index.html': '/',
  '/en.html': '/en',
  '/fr.html': '/fr',
}

const TRAILING_SLASH_NORMALIZATIONS = {
  '/en/': '/en',
  '/fr/': '/fr',
  '/site/': '/site',
  '/Website/': '/Website',
}

const INFO_ROUTES = [
  '/privacy', '/support', '/legal', '/licenses',
  '/fr/privacy', '/fr/support', '/fr/legal', '/fr/licenses',
]
const REQUIRED_ASSETS = [
  '/favicon.svg',
  '/favicon.ico',
  '/manifest.webmanifest',
  '/robots.txt',
  '/sitemap.xml',
  '/latest.json',
  '/SHA256SUMS',
  '/assets/shell/boot.js',
  '/assets/shell/public.css',
  '/assets/shell/public.js',
  '/assets/brand/favicon.svg',
  '/assets/brand/favicon-v2-16.png',
  '/assets/brand/favicon-v2-32.png',
  '/assets/brand/favicon-v2-180.png',
  '/assets/brand/favicon-v2-192.png',
  '/assets/brand/favicon-v2-512.png',
  '/assets/brand/opengraph.png',
  '/assets/fonts/archivo-latin.woff2',
  '/assets/fonts/plexmono-400-latin.woff2',
  '/assets/tokens/design-tokens.css',
  '/assets/tokens/design-tokens.json',
  '/assets/licenses/Archivo-OFL.txt',
  '/assets/licenses/IBM-Plex-OFL.txt',
]

const build = await buildSite()
const publishedRelease = JSON.parse(await readFile(join(repoRoot, 'Configuration', 'published-release.json'), 'utf8'))
const externalOrigin = process.env.SITE_BASE_URL?.replace(/\/$/, '')
const fixture = externalOrigin ? null : await startSite(build.output)
const origin = externalOrigin ?? fixture.origin
const { chromium } = await loadPlaywright()
const browser = await launchChromium(chromium)
const failures = []
let passes = 0

async function gate(name, action) {
  const started = performance.now()
  try {
    await action()
    passes++
    console.log(`PASS — ${name} (${Math.round(performance.now() - started)} ms)`)
  } catch (error) {
    failures.push({ name, error })
    console.error(`FAIL — ${name}\n${error.stack ?? error}`)
  }
}

async function responseAt(path, options = {}) {
  return fetch(`${origin}${path}`, { redirect: 'manual', ...options })
}

function normalizedLocation(response) {
  const location = response.headers.get('location') ?? ''
  if (!location) return ''
  const target = new URL(location, origin)
  return target.origin === origin ? `${target.pathname}${target.search}${target.hash}` : target.href
}

function watchPage(page) {
  const problems = []
  page.on('console', message => {
    if (message.type() === 'error' && !/^Failed to load resource: the server responded with a status of 404\b/.test(message.text())) {
      problems.push(`console: ${message.text()}`)
    }
  })
  page.on('pageerror', error => problems.push(`pageerror: ${error.message}`))
  page.on('response', response => {
    const target = new URL(response.url())
    if (target.origin === origin && response.status() >= 400 && response.request().resourceType() !== 'document') {
      problems.push(`http: ${target.pathname} (${response.status()})`)
    }
  })
  page.on('requestfailed', request => {
    const target = new URL(request.url())
    const kind = request.resourceType()
    if (target.origin === origin && !['media'].includes(kind)) {
      problems.push(`requestfailed: ${target.pathname} (${request.failure()?.errorText ?? 'unknown'})`)
    }
  })
  return problems
}

async function loadAxeBuilder() {
  try {
    return (await import('@axe-core/playwright')).default
  } catch (primaryError) {
    const candidates = [
      process.env.CORETEND_NODE_MODULES,
      resolve(repoRoot, '..', '..', '..', 'ahmetbsbnr-portfolio', 'node_modules'),
    ].filter(Boolean)
    for (const modules of candidates) {
      try {
        return (await import(pathToFileURL(join(modules, '@axe-core', 'playwright', 'dist', 'index.mjs')).href)).default
      } catch {}
    }
    throw new Error(`@axe-core/playwright is required (${primaryError.message})`)
  }
}

await gate('isolated production build and public-output allow-list', async () => {
  assert.match(build.log, /Built public CoreTend site:/)
  const output = await scanPublicOutput(build.output)
  assert(output.files > 20)
})

await gate('release identity is generated from one canonical record', async () => {
  const template = await readFile(join(repoRoot, 'Website', 'index.html'), 'utf8')
  assert(!/0\.9\.1-rc\.\d+/i.test(template), 'landing template contains a hard-coded release version')
  for (const token of [
    '@@CORETEND_RELEASE_VERSION@@',
    '@@CORETEND_DMG_SHA256@@',
    '@@CORETEND_MINIMUM_MACOS@@',
    '@@CORETEND_ARCHITECTURE@@',
  ]) assert(template.includes(token), `landing template is missing ${token}`)

  for (const file of ['index.html', 'en-route.html', 'fr-route.html', 'support.html', 'fr-support.html']) {
    const document = await readFile(join(build.output, file), 'utf8')
    assert(document.includes(publishedRelease.version), `${file} does not render ${publishedRelease.version}`)
    assert(document.includes(publishedRelease.dmgSHA256), `${file} does not render the canonical checksum`)
    assert(!document.includes('@@CORETEND_'), `${file} exposes an unresolved release token`)
  }
})

await gate('root and Website Vercel route contracts cannot drift', async () => {
  const rootConfig = JSON.parse(await readFile(join(repoRoot, 'vercel.json'), 'utf8'))
  const websiteConfig = JSON.parse(await readFile(join(repoRoot, 'Website', 'vercel.json'), 'utf8'))
  assert.deepEqual(rootConfig.redirects, websiteConfig.redirects)
  assert.deepEqual(rootConfig.rewrites, websiteConfig.rewrites)
  assert.deepEqual(rootConfig.headers, websiteConfig.headers)
  assert.equal(rootConfig.outputDirectory, 'Website/dist')
  assert.equal(websiteConfig.outputDirectory, 'dist')
  assert.match(rootConfig.buildCommand, /Website\/build\.py/)
  assert.match(websiteConfig.buildCommand, /(?:^|\s)build\.py/)
  for (const rule of rootConfig.redirects) {
    assert(!/\(\.\*\)|:\w+\*/.test(rule.source), `blind catch-all redirect: ${rule.source}`)
    if (!/^https:\/\//.test(rule.destination)) {
      assert(!/\.html(?:$|[?#/])/.test(rule.destination), `redirect exposes HTML: ${rule.destination}`)
      assert(!/\/(?:site|Website|public|dist|out)(?:\/|$)/.test(rule.destination), `redirect exposes internal directory: ${rule.destination}`)
    }
  }
})

await gate('canonical routes and required assets return successful HTTP codes', async () => {
  for (const route of CANONICAL_ROUTES) {
    const response = await responseAt(route)
    assert.equal(response.status, 200, `${route} returned ${response.status}`)
  }
  for (const asset of REQUIRED_ASSETS) {
    const response = await responseAt(asset)
    assert.equal(response.status, 200, `${asset} returned ${response.status}`)
    assert(Number(response.headers.get('content-length')) > 0, `${asset} is empty`)
  }

  const generatedDirectory = join(build.output, 'assets', 'generated')
  for (const name of await readdir(generatedDirectory)) {
    const response = await responseAt(`/assets/generated/${name}`)
    assert.equal(response.status, 200, `/assets/generated/${name} returned ${response.status}`)
  }
})

await gate('historic routes and slash normalization reach clean canonical destinations', async () => {
  for (const [source, destination] of Object.entries(REDIRECTS)) {
    const response = await responseAt(source)
    assert([301, 308].includes(response.status), `${source} is not permanent (${response.status})`)
    assert.equal(normalizedLocation(response), destination, `${source} has the wrong destination`)
    const target = await responseAt(destination)
    assert.equal(target.status, 200, `${source} creates a redirect chain or broken target`)
  }
  for (const [source, destination] of Object.entries(TRAILING_SLASH_NORMALIZATIONS)) {
    const response = await responseAt(source)
    assert.equal(response.status, 308, `${source} is not normalized permanently`)
    assert.equal(normalizedLocation(response), destination, `${source} has the wrong normalized destination`)
    const target = await responseAt(destination)
    if (destination === '/en' || destination === '/fr') {
      assert.equal(target.status, 200, `${source} does not normalize to a canonical locale route`)
    } else {
      assert.equal(target.status, 308, `${source} does not continue through its known historic redirect`)
      assert.equal(normalizedLocation(target), '/')
      assert.equal((await responseAt('/')).status, 200)
    }
  }
  const download = await responseAt('/download')
  assert.equal(download.status, 307, '/download must remain a temporary redirect to the reviewed binary')
  assert.equal(normalizedLocation(download), publishedRelease.dmgURL)
})

await gate('unknown routes return the branded 404 with no redirect', async () => {
  for (const route of ['/definitely-not-a-route', '/en/unknown', '/en/obsolete.html', '/fr/obsolete.html', '/assets/not-present.css']) {
    const response = await responseAt(route)
    assert.equal(response.status, 404, `${route} returned ${response.status}`)
    const body = await response.text()
    assert.match(body, /outside the map/)
    assert.match(body, /hors carte/)
    assert.match(body, /assets\/shell\/public\.css/)
  }
})

await gate('branded 404 uses the available viewport without trailing blank space', async () => {
  const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 430, height: 932 } })
  const page = await context.newPage()
  const response = await page.goto(`${origin}/missing-layout-proof`, { waitUntil: 'networkidle' })
  assert.equal(response.status(), 404)
  const geometry = await page.evaluate(() => ({
    viewport: innerHeight,
    footerBottom: document.querySelector('footer')?.getBoundingClientRect().bottom ?? 0,
    horizontalOverflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
  }))
  assert(geometry.footerBottom >= geometry.viewport - 1, `404 leaves ${(geometry.viewport - geometry.footerBottom).toFixed(0)}px blank below its footer`)
  assert(geometry.horizontalOverflow <= 1)
  await context.close()
})

await gate('canonical, hreflang, Open Graph and document languages are exact', async () => {
  const context = await browser.newContext({ javaScriptEnabled: false })
  const page = await context.newPage()
  const expectations = [
    ['/', 'en'], ['/en', 'en'], ['/fr', 'fr'],
    ['/privacy', 'en'], ['/support', 'en'], ['/legal', 'en'], ['/licenses', 'en'],
    ['/fr/privacy', 'fr'], ['/fr/support', 'fr'], ['/fr/legal', 'fr'], ['/fr/licenses', 'fr'],
  ]
  const titles = new Map()
  for (const [route, language] of expectations) {
    const response = await page.goto(`${origin}${route}`, { waitUntil: 'networkidle' })
    assert.equal(response.status(), 200)
    const meta = await page.evaluate(() => ({
      lang: document.documentElement.lang,
      title: document.title,
      canonical: document.querySelector('link[rel="canonical"]')?.href,
      alternates: Object.fromEntries([...document.querySelectorAll('link[rel="alternate"][hreflang]')].map(link => [link.hreflang, link.href])),
      ogUrl: document.querySelector('meta[property="og:url"]')?.content,
      ogTitle: document.querySelector('meta[property="og:title"]')?.content,
      description: document.querySelector('meta[name="description"]')?.content,
    }))
    assert.equal(meta.lang, language, `${route} has lang=${meta.lang}`)
    assert.equal(meta.canonical, EXPECTED_CANONICAL[route])
    assert.equal(meta.ogUrl, EXPECTED_CANONICAL[route])
    assert(meta.title && meta.description && meta.ogTitle)
    assert(!/\.html(?:$|[?#/])/.test(meta.canonical))
    if (['/', '/en', '/fr'].includes(route)) {
      assert.deepEqual(meta.alternates, {
        en: 'https://coretend.ahmetbsbnr.com/en',
        fr: 'https://coretend.ahmetbsbnr.com/fr',
        'x-default': 'https://coretend.ahmetbsbnr.com/',
      })
    } else {
      const englishRoute = route.replace(/^\/fr/, '')
      assert.deepEqual(meta.alternates, {
        en: `https://coretend.ahmetbsbnr.com${englishRoute}`,
        fr: `https://coretend.ahmetbsbnr.com/fr${englishRoute}`,
        'x-default': `https://coretend.ahmetbsbnr.com${englishRoute}`,
      })
    }
    titles.set(route, meta.title)
  }
  assert.notEqual(titles.get('/en'), titles.get('/fr'), 'localized titles must differ')
  await context.close()
})

await gate('French is pre-rendered and every authored translation remains valid HTML', async () => {
  const context = await browser.newContext({ javaScriptEnabled: false })
  const page = await context.newPage()
  await page.goto(`${origin}/en`)
  const english = await page.locator('[data-fr]').evaluateAll(elements => elements.map(element => ({
    translation: element.getAttribute('data-fr')?.trim() ?? '',
    content: element.innerHTML.trim(),
  })))
  await page.goto(`${origin}/fr`)
  const french = await page.locator('[data-fr]').evaluateAll(elements => elements.map(element => ({
    translation: element.getAttribute('data-fr')?.trim() ?? '',
    content: element.innerHTML.trim(),
  })))
  assert.equal(french.length, english.length)
  assert(english.length >= 100, `translation inventory unexpectedly small (${english.length})`)
  english.forEach((entry, index) => {
    assert(entry.translation, `translation ${index} is empty`)
    assert(entry.content, `English content ${index} is empty`)
  })
  french.forEach((entry, index) => {
    assert(entry.content, `French content ${index} is empty`)
    assert(!entry.content.includes('undefined'), `French content ${index} exposes undefined`)
    assert(!entry.content.match(/\bdata-fr\s*=/), `French content ${index} has broken nested markup`)
  })
  assert.match(await page.locator('#headline').innerText(), /^Sachez ce que votre Mac garde\./)
  assert(!((await page.locator('body').innerText()).includes('Know what your Mac is holding.')))
  await context.close()
})

await gate('French localizes visible calls to action and accessible control names', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce', locale: 'fr-FR' })
  const page = await context.newPage()
  await page.goto(`${origin}/fr`)
  const sourceCallToAction = await page.locator('.hero .btn-secondary span').innerText()
  assert(!/Read the source/i.test(sourceCallToAction) && /(?:code|source)/i.test(sourceCallToAction))
  assert.match(await page.locator('.skip').innerText(), /Aller/i)
  assert.match(await page.locator('.bar .wordmark').getAttribute('aria-label'), /accueil/i)
  assert.match(await page.locator('#theme').getAttribute('aria-label'), /(?:apparence|thème)/i)
  const appLabel = await page.locator('#app').getAttribute('aria-label')
  assert(/CoreTend/i.test(appLabel) && /(?:aperçu|interface)/i.test(appLabel) && !/preview/i.test(appLabel))
  assert.match(await page.locator('#tabs').getAttribute('aria-label'), /(?:catégories|résultats|trouvailles)/i)
  assert.equal((await page.locator('#copy').innerText()).trim(), 'Copier')

  const views = {
    storage: 'Stockage', lens: 'Space Lens', dupes: 'Doublons',
    apps: 'Applications', integrity: 'Intégrité', activity: 'Activité',
  }
  for (const [id, title] of Object.entries(views)) {
    await page.locator(`[data-view="${id}"]`).click()
    assert.equal(await page.locator('#vTitle').innerText(), title)
  }
  await context.close()
})

await gate('browser language routing and manual language persistence have no loop', async () => {
  const frenchContext = await browser.newContext({ locale: 'fr-FR', reducedMotion: 'reduce' })
  const frenchPage = await frenchContext.newPage()
  await frenchPage.goto(`${origin}/`)
  await frenchPage.waitForURL(`${origin}/fr`)
  assert.equal(await frenchPage.getAttribute('html', 'lang'), 'fr')
  await frenchContext.close()

  const context = await browser.newContext({ locale: 'fr-FR', reducedMotion: 'reduce' })
  const page = await context.newPage()
  await page.goto(`${origin}/en#top`)
  await page.locator('[data-view="apps"]').click()
  await page.locator('[data-lang-link="fr"]').click()
  await page.waitForURL(`${origin}/fr#top`)
  assert.equal(await page.evaluate(() => localStorage.getItem('coretend-language')), 'fr')
  assert.equal(await page.evaluate(() => location.hash), '#top')
  assert(await page.locator('[data-view="apps"]').evaluate(button => button.classList.contains('on')), 'active app view was lost across language switch')
  await page.goto(`${origin}/`)
  await page.waitForURL(`${origin}/fr`)
  await context.close()
})

await gate('system theme, manual theme and persistence work across routes', async () => {
  const context = await browser.newContext({ colorScheme: 'dark', reducedMotion: 'reduce' })
  const page = await context.newPage()
  await page.goto(`${origin}/en`)
  assert.equal(await page.getAttribute('html', 'data-theme'), 'dark')
  await page.locator('#theme').click()
  assert.equal(await page.getAttribute('html', 'data-theme'), 'light')
  assert.equal(await page.evaluate(() => localStorage.getItem('coretend-theme')), 'light')
  await page.reload()
  assert.equal(await page.getAttribute('html', 'data-theme'), 'light')
  await page.goto(`${origin}/fr`)
  assert.equal(await page.getAttribute('html', 'data-theme'), 'light')
  await page.locator('#theme').click()
  assert.equal(await page.getAttribute('html', 'data-theme-mode'), 'dark')
  assert.equal(await page.getAttribute('html', 'data-theme'), 'dark')
  await page.locator('#theme').click()
  assert.equal(await page.getAttribute('html', 'data-theme-mode'), 'system')
  assert.equal(await page.getAttribute('html', 'data-theme'), 'dark')
  await page.goto(`${origin}/fr/privacy`)
  assert.equal(await page.getAttribute('html', 'data-theme-mode'), 'system')
  assert.equal(await page.getAttribute('html', 'data-theme'), 'dark')
  await context.close()
})

await gate('every information route uses the shared living shell', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce', viewport: { width: 1280, height: 800 } })
  const page = await context.newPage()
  for (const route of INFO_ROUTES) {
    const problems = watchPage(page)
    const response = await page.goto(`${origin}${route}`, { waitUntil: 'networkidle' })
    assert.equal(response.status(), 200, `${route} returned ${response.status()}`)
    const state = await page.evaluate(() => ({
      language: document.documentElement.lang,
      page: document.body.dataset.page,
      canvas: document.querySelector('#field')?.getAttribute('aria-hidden'),
      headerLogo: document.querySelectorAll('header .ct-logo').length,
      footerLogo: document.querySelectorAll('footer .ct-logo').length,
      arcs: [...document.querySelectorAll('.ct-logo')].map(logo => logo.querySelectorAll(':scope > .ct-arc').length),
      cores: document.querySelectorAll('.ct-logo > .ct-core').length,
      wholeTransforms: [...document.querySelectorAll('.ct-logo')].map(logo => getComputedStyle(logo).transform),
      coreTransforms: [...document.querySelectorAll('.ct-core')].map(core => getComputedStyle(core).transform),
      footerLinks: document.querySelectorAll('footer a').length,
      stylesheets: [...document.querySelectorAll('link[rel="stylesheet"]')].map(link => new URL(link.href).pathname),
    }))
    assert.equal(state.language, route.startsWith('/fr/') ? 'fr' : 'en')
    assert.equal(state.canvas, 'true')
    assert.equal(state.headerLogo, 1)
    assert.equal(state.footerLogo, 1)
    assert(state.arcs.every(count => count === 3), `${route} logo is not composed of three independent arcs`)
    assert.equal(state.cores, state.arcs.length, `${route} must keep one fixed core per logo`)
    assert(state.wholeTransforms.every(value => ['none', 'matrix(1, 0, 0, 1, 0, 0)'].includes(value)), `${route} transforms the complete logo`)
    assert(state.coreTransforms.every(value => ['none', 'matrix(1, 0, 0, 1, 0, 0)'].includes(value)), `${route} transforms the fixed core`)
    assert(state.footerLinks >= 6)
    assert(state.stylesheets.includes('/assets/shell/public.css'))
    assert.deepEqual(problems, [], `${route} emitted browser errors`)
  }
  await context.close()
})

await gate('Axe finds no WCAG A or AA violations on any public page', async () => {
  const AxeBuilder = await loadAxeBuilder()
  const routes = ['/en', '/fr', ...INFO_ROUTES, '/axe-not-found']
  for (const colorScheme of ['light', 'dark']) {
    const context = await browser.newContext({ colorScheme, reducedMotion: 'reduce', viewport: { width: 1280, height: 800 } })
    const page = await context.newPage()
    for (const route of routes) {
      const response = await page.goto(`${origin}${route}`, { waitUntil: 'networkidle' })
      assert([200, 404].includes(response.status()), `${route} returned ${response.status()}`)
      const result = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
        .analyze()
      if (result.violations.length) {
        throw new Error(`${route}/${colorScheme}: ${result.violations.map(violation => `${violation.id} (${violation.nodes.length})`).join(', ')}`)
      }
    }
    await context.close()
  }
})

await gate('workflow title never overlays its steps below the two-column breakpoint', async () => {
  for (const viewport of [{ width: 820, height: 1180 }, { width: 430, height: 932 }, { width: 360, height: 800 }]) {
    for (const language of ['en', 'fr']) {
      const context = await browser.newContext({ viewport, reducedMotion: 'reduce' })
      const page = await context.newPage()
      await page.goto(`${origin}/${language}/`, { waitUntil: 'networkidle' })
      const geometry = await page.locator('#how').evaluate(section => {
        const heading = section.querySelector('.flow-sticky')
        const firstStep = section.querySelector('.steps li')
        const headingRect = heading.getBoundingClientRect()
        const stepRect = firstStep.getBoundingClientRect()
        return {
          position: getComputedStyle(heading).position,
          headingBottom: headingRect.bottom,
          stepTop: stepRect.top,
        }
      })
      assert.equal(geometry.position, 'static', `${language}/${viewport.width}px workflow heading remains sticky`)
      assert(geometry.stepTop >= geometry.headingBottom - 1, `${language}/${viewport.width}px workflow content overlaps by ${(geometry.headingBottom - geometry.stepTop).toFixed(1)}px`)
      await context.close()
    }
  }
})

await gate('six application views switch without an empty state', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce' })
  const page = await context.newPage()
  const problems = watchPage(page)
  await page.goto(`${origin}/en`, { waitUntil: 'networkidle' })
  const views = {
    storage: 'Storage', lens: 'Space Lens', dupes: 'Duplicates',
    apps: 'Applications', integrity: 'Integrity', activity: 'Activity',
  }
  for (const [id, title] of Object.entries(views)) {
    const button = page.locator(`[data-view="${id}"]`)
    await button.click()
    assert.equal(await page.locator('#vTitle').innerText(), title)
    assert(await button.evaluate(element => element.classList.contains('on')))
    assert(await page.locator('#vRows > div').count() > 0)
    const selectedState = await button.evaluate(element => element.getAttribute('aria-current') ?? element.getAttribute('aria-pressed'))
    assert(['page', 'true'].includes(selectedState), `${id} selection is not exposed to assistive technology`)
  }
  assert.deepEqual(problems, [])
  await context.close()
})

await gate('scan pause, resume and cancel preserve causal progress', async () => {
  const context = await browser.newContext({ reducedMotion: 'no-preference' })
  const page = await context.newPage()
  await page.goto(`${origin}/en`, { waitUntil: 'domcontentloaded' })
  await page.locator('[data-view="storage"]').click()
  await page.waitForFunction(() => parseFloat(document.querySelector('#vTrack')?.style.width) > 2, null, { timeout: 2000 })
  const beforePause = parseFloat(await page.locator('#vTrack').evaluate(element => element.style.width))
  assert(beforePause > 2 && beforePause < 50, `unexpected pre-pause progress ${beforePause}`)
  await page.locator('#scanToggle').click()
  assert.equal(await page.locator('#app').getAttribute('data-scan'), 'paused')
  const paused = parseFloat(await page.locator('#vTrack').evaluate(element => element.style.width))
  await page.waitForTimeout(450)
  const stillPaused = parseFloat(await page.locator('#vTrack').evaluate(element => element.style.width))
  assert(Math.abs(paused - stillPaused) < 0.15, `progress continued during pause (${paused} -> ${stillPaused})`)
  await page.locator('#scanToggle').click()
  assert.equal(await page.locator('#app').getAttribute('data-scan'), 'scanning')
  await page.waitForTimeout(450)
  const resumed = parseFloat(await page.locator('#vTrack').evaluate(element => element.style.width))
  assert(resumed > stillPaused + 2, `resume restarted or failed to advance (${stillPaused} -> ${resumed})`)
  await page.locator('#scanCancel').click()
  assert.equal(await page.locator('#app').getAttribute('data-scan'), 'cancelled')
  assert.match(await page.locator('#vFoot').innerText(), /cancelled.*Nothing was removed/i)
  const cancelled = parseFloat(await page.locator('#vTrack').evaluate(element => element.style.width))
  await page.waitForTimeout(350)
  assert.equal(parseFloat(await page.locator('#vTrack').evaluate(element => element.style.width)), cancelled)
  await context.close()
})

await gate('application preview auto-cycles after a completed scan', async () => {
  const context = await browser.newContext({ reducedMotion: 'no-preference' })
  const page = await context.newPage()
  await page.goto(`${origin}/en`, { waitUntil: 'domcontentloaded' })
  await page.waitForFunction(() => document.querySelector('[data-view="lens"]')?.classList.contains('on'), null, { timeout: 7500 })
  assert.equal(await page.locator('#vTitle').innerText(), 'Space Lens')
  await context.close()
})

await gate('Findings tabs, totals and keyboard navigation are functional', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce' })
  const page = await context.newPage()
  await page.goto(`${origin}/en`)
  const totals = new Set()
  for (const category of ['storage', 'dupes', 'apps']) {
    const tab = page.locator(`#tabs [data-cat="${category}"]`)
    await tab.click()
    assert.equal(await tab.getAttribute('aria-selected'), 'true')
    assert(await page.locator('#findRows > div').count() > 0)
    totals.add(await page.locator('#findTotal').innerText())
  }
  assert.equal(totals.size, 3)
  const first = page.locator('#tabs [role="tab"]').first()
  await first.focus()
  await page.keyboard.press('ArrowRight')
  assert.equal(await page.locator('#tabs [role="tab"][aria-selected="true"]').getAttribute('data-cat'), 'dupes')
  assert.equal(await page.evaluate(() => document.activeElement?.getAttribute('data-cat')), 'dupes')
  await context.close()
})

await gate('FAQ opens and closes, checksum copies, and keyboard focus is visible', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce', permissions: ['clipboard-read', 'clipboard-write'] })
  const page = await context.newPage()
  await page.goto(`${origin}/en`)
  await page.keyboard.press('Tab')
  assert(await page.locator('.skip').evaluate(element => element === document.activeElement))
  const outline = await page.locator('.skip').evaluate(element => getComputedStyle(element).outlineStyle)
  assert.notEqual(outline, 'none')

  const item = page.locator('.faq details').first()
  await item.locator('summary').click()
  assert(await item.evaluate(element => element.open))
  await item.locator('summary').click()
  await page.waitForFunction(element => !element.open, await item.elementHandle(), { timeout: 1000 })

  const expected = (await page.locator('#sha').innerText()).trim()
  await page.locator('#copy').click()
  assert.equal(await page.evaluate(() => navigator.clipboard.readText()), expected)
  assert.match(await page.locator('#toast').innerText(), /Checksum copied/)
  await context.close()
})

await gate('reduced motion is static, complete and keeps the logo core fixed', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce' })
  const page = await context.newPage()
  await page.goto(`${origin}/en`, { waitUntil: 'networkidle' })
  await page.waitForTimeout(100)
  const state = await page.evaluate(() => ({
    scan: document.querySelector('#app')?.getAttribute('data-scan'),
    coreTransforms: [...document.querySelectorAll('.ct-core')].map(element => getComputedStyle(element).transform),
    logoTransforms: [...document.querySelectorAll('.ct-logo')].map(element => getComputedStyle(element).transform),
    hiddenReveals: [...document.querySelectorAll('[data-reveal]')].filter(element => {
      const style = getComputedStyle(element)
      return style.visibility === 'hidden' || Number(style.opacity) < 0.99
    }).length,
    runningInfinite: document.getAnimations({ subtree: true }).filter(animation => {
      const timing = animation.effect?.getComputedTiming()
      return timing?.iterations === Infinity && animation.playState === 'running'
    }).length,
  }))
  assert.equal(state.scan, 'complete')
  assert(state.coreTransforms.every(value => value === 'none' || value === 'matrix(1, 0, 0, 1, 0, 0)'))
  assert(state.logoTransforms.every(value => value === 'none' || value === 'matrix(1, 0, 0, 1, 0, 0)'))
  assert.equal(state.hiddenReveals, 0)
  assert.equal(state.runningInfinite, 0, `${state.runningInfinite} infinite animation(s) still run with reduced motion`)
  await context.close()
})

await gate('logo arcs orbit independently while the symbol and core stay fixed', async () => {
  const context = await browser.newContext({ reducedMotion: 'no-preference', viewport: { width: 1440, height: 900 } })
  const page = await context.newPage()
  await page.goto(`${origin}/en`, { waitUntil: 'domcontentloaded' })
  await page.evaluate(() => document.fonts.ready)
  await page.waitForTimeout(2600)
  const before = await page.locator('.ct-logo--hero').evaluate(logo => {
    const core = logo.querySelector('.ct-core').getBoundingClientRect()
    return {
      logo: getComputedStyle(logo).transform,
      core: { x: core.x + core.width / 2, y: core.y + core.height / 2, transform: getComputedStyle(logo.querySelector('.ct-core')).transform },
      arcs: [...logo.querySelectorAll('.ct-arc')].map(arc => getComputedStyle(arc).transform),
      rates: logo._ctOrbit?.animations.map(({ animation }) => animation.playbackRate) ?? [],
    }
  })
  await page.waitForTimeout(350)
  const after = await page.locator('.ct-logo--hero').evaluate(logo => {
    const core = logo.querySelector('.ct-core').getBoundingClientRect()
    return {
      logo: getComputedStyle(logo).transform,
      core: { x: core.x + core.width / 2, y: core.y + core.height / 2, transform: getComputedStyle(logo.querySelector('.ct-core')).transform },
      arcs: [...logo.querySelectorAll('.ct-arc')].map(arc => getComputedStyle(arc).transform),
    }
  })
  assert(['none', 'matrix(1, 0, 0, 1, 0, 0)'].includes(before.logo), `whole hero logo is transformed: ${before.logo}`)
  assert(['none', 'matrix(1, 0, 0, 1, 0, 0)'].includes(after.logo), `whole hero logo is transformed: ${after.logo}`)
  assert(['none', 'matrix(1, 0, 0, 1, 0, 0)'].includes(before.core.transform), `core is transformed: ${before.core.transform}`)
  assert(Math.abs(before.core.x - after.core.x) < 0.05 && Math.abs(before.core.y - after.core.y) < 0.05, 'core moved during orbit')
  assert.equal(new Set(before.arcs).size, 3, 'the three arcs share the same phase')
  assert(before.arcs.every((transform, index) => transform !== after.arcs[index]), 'one or more arcs did not orbit')

  await page.locator('.hero-mark').hover()
  await page.waitForTimeout(380)
  const accelerated = await page.locator('.ct-logo--hero').evaluate(logo => logo._ctOrbit.animations.map(({ animation }) => animation.playbackRate))
  assert(accelerated.every(rate => rate > 1.35), `hover did not smoothly accelerate every arc (${accelerated.join(', ')})`)
  await context.close()
})

await gate('semantic controls have unique IDs, names and one accessible logo identity', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce' })
  const page = await context.newPage()
  await page.goto(`${origin}/en`)
  const audit = await page.evaluate(() => {
    const ids = [...document.querySelectorAll('[id]')].map(element => element.id)
    const duplicates = [...new Set(ids.filter((id, index) => ids.indexOf(id) !== index))]
    const unnamedButtons = [...document.querySelectorAll('button')].filter(button => {
      const name = button.getAttribute('aria-label') || button.textContent?.trim()
      return !name
    }).length
    return {
      duplicates,
      unnamedButtons,
      decorativeCanvas: document.querySelector('#field')?.getAttribute('aria-hidden'),
      labelledLogos: [...document.querySelectorAll('.ct-logo[aria-label]')].map(logo => logo.getAttribute('aria-label')),
    }
  })
  assert.deepEqual(audit.duplicates, [])
  assert.equal(audit.unnamedButtons, 0)
  assert.equal(audit.decorativeCanvas, 'true')
  assert.deepEqual(audit.labelledLogos, ['CoreTend', 'CoreTend'])
  await context.close()
})

await gate('published raster brand assets contain no historical palette', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce' })
  const page = await context.newPage()
  await page.goto(`${origin}/privacy`)
  const matches = await page.evaluate(async sources => {
    const historical = [
      [19, 103, 74], [92, 84, 204], [148, 96, 10],
      [168, 230, 193], [155, 138, 251], [244, 199, 107],
    ]
    const findings = []
    for (const source of sources) {
      const image = new Image()
      image.src = source
      await image.decode()
      const scale = Math.min(1, 640 / Math.max(image.naturalWidth, image.naturalHeight))
      const width = Math.max(1, Math.round(image.naturalWidth * scale))
      const height = Math.max(1, Math.round(image.naturalHeight * scale))
      const canvas = document.createElement('canvas')
      canvas.width = width
      canvas.height = height
      const drawing = canvas.getContext('2d', { willReadFrequently: true })
      drawing.drawImage(image, 0, 0, width, height)
      const pixels = drawing.getImageData(0, 0, width, height).data
      let count = 0
      for (let index = 0; index < pixels.length; index += 4) {
        if (pixels[index + 3] < 180) continue
        if (historical.some(([r, g, b]) => Math.abs(pixels[index] - r) <= 3 && Math.abs(pixels[index + 1] - g) <= 3 && Math.abs(pixels[index + 2] - b) <= 3)) count++
      }
      if (count) findings.push(`${source}:${count}`)
    }
    return findings
  }, [
    '/assets/brand/favicon-v2-16.png',
    '/assets/brand/favicon-v2-32.png',
    '/assets/brand/favicon-v2-180.png',
    '/assets/brand/favicon-v2-192.png',
    '/assets/brand/favicon-v2-512.png',
    '/assets/brand/opengraph.png',
  ])
  assert.deepEqual(matches, [], `historical green/purple/amber pixels remain: ${matches.join(', ')}`)
  await context.close()
})

await gate('favicons preserve the complete centered CoreTend mark at every size', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce' })
  const page = await context.newPage()
  await page.goto(`${origin}/privacy`)
  const [rootSvg, canonicalSvg] = await Promise.all([
    page.evaluate(() => fetch('/favicon.svg').then(response => response.text())),
    page.evaluate(() => fetch('/assets/brand/favicon.svg').then(response => response.text())),
  ])
  assert.equal(rootSvg, canonicalSvg, 'root favicon.svg diverges from the canonical brand asset')
  const records = await page.evaluate(async sizes => {
    const result = []
    for (const size of sizes) {
      const image = new Image()
      image.src = `/assets/brand/favicon-v2-${size}.png`
      await image.decode()
      const canvas = document.createElement('canvas')
      canvas.width = image.naturalWidth
      canvas.height = image.naturalHeight
      const drawing = canvas.getContext('2d', { willReadFrequently: true })
      drawing.drawImage(image, 0, 0)
      const pixels = drawing.getImageData(0, 0, canvas.width, canvas.height).data
      const centerIndex = (Math.floor(canvas.height / 2) * canvas.width + Math.floor(canvas.width / 2)) * 4
      let nonBackground = 0
      let transparent = 0
      for (let index = 0; index < pixels.length; index += 4) {
        if (pixels[index + 3] <= 8) transparent++
        if (pixels[index + 3] > 32) nonBackground++
      }
      result.push({
        requested: size,
        width: canvas.width,
        height: canvas.height,
        center: [...pixels.slice(centerIndex, centerIndex + 4)],
        coverage: nonBackground / (canvas.width * canvas.height),
        transparency: transparent / (canvas.width * canvas.height),
      })
    }
    return result
  }, [16, 32, 180, 192, 512])
  for (const record of records) {
    assert.equal(record.width, record.requested)
    assert.equal(record.height, record.requested)
    const [red, green, blue, alpha] = record.center
    // The mark's nucleus is a teal radial gradient (Canonical.cobaltBright
    // #5FD3C6 -> Canonical.cobaltDeep #08514F). The sampled centre lands
    // partway along it, drifting a little darker as downscaling folds in the
    // gradient edge at 16px. Anchor near the 32-512px cluster with enough
    // tolerance to cover that drift.
    assert(alpha > 240 && Math.abs(red - 66) < 20 && Math.abs(green - 168) < 20 && Math.abs(blue - 158) < 20, `${record.requested}px favicon lost the fixed teal core (${record.center})`)
    assert(record.coverage > 0.12, `${record.requested}px favicon mark coverage is only ${(record.coverage * 100).toFixed(1)}%`)
    assert(record.transparency > 0.35, `${record.requested}px favicon has an opaque background (${(record.transparency * 100).toFixed(1)}% transparent)`)
  }
  await context.close()
})

await gate('landing consumes the generated Swift design tokens', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce' })
  const page = await context.newPage()
  await page.goto(`${origin}/en`)
  const state = await page.evaluate(async () => {
    const stylesheets = [...document.querySelectorAll('link[rel="stylesheet"]')].map(link => new URL(link.href).pathname)
    const style = getComputedStyle(document.documentElement)
    const value = name => style.getPropertyValue(name).trim().toLowerCase()
    const tokens = await fetch('/assets/tokens/design-tokens.json').then(response => response.json())
    return {
      stylesheets,
      source: tokens.source,
      colors: {
        cobalt: [value('--cobalt'), value('--ct-cobalt')],
        ink: [value('--ink'), value('--ct-ink')],
        paper: [value('--paper'), value('--ct-paper')],
      },
    }
  })
  assert(state.stylesheets.includes('/assets/tokens/design-tokens.css'), 'generated token stylesheet is published but not consumed')
  assert.equal(state.source, 'Sources/DesignSystem/Colors.swift + Tokens.swift')
  for (const [name, [siteValue, tokenValue]] of Object.entries(state.colors)) {
    assert(tokenValue, `generated --ct-${name} is missing`)
    assert.equal(siteValue, tokenValue, `site ${name} diverges from Swift token (${siteValue} vs ${tokenValue})`)
  }
  await context.close()
})

await gate('no-JavaScript fallback remains styled, bilingual and usable', async () => {
  const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 390, height: 844 } })
  const page = await context.newPage()
  const problems = watchPage(page)
  let response = await page.goto(`${origin}/`, { waitUntil: 'networkidle' })
  assert.equal(response.status(), 200)
  assert.equal(new URL(page.url()).pathname, '/')
  assert.match(await page.locator('#headline').innerText(), /^Know what your Mac is holding/)
  assert(await page.locator('[data-lang-link="fr"]').isVisible())
  assert(await page.locator('#sha').isVisible())
  assert((await page.evaluate(() => [...document.styleSheets].filter(sheet => !sheet.disabled).length)) > 0)

  response = await page.goto(`${origin}/fr`, { waitUntil: 'networkidle' })
  assert.equal(response.status(), 200)
  assert.match(await page.locator('#headline').innerText(), /^Sachez ce que votre Mac garde/)
  const faq = page.locator('.faq details').first()
  await faq.locator('summary').click()
  assert(await faq.evaluate(element => element.open), 'native FAQ does not work without JavaScript')
  for (const route of INFO_ROUTES) {
    response = await page.goto(`${origin}${route}`, { waitUntil: 'networkidle' })
    assert.equal(response.status(), 200, `${route} is unavailable without JavaScript`)
    assert(await page.locator('header .wordmark').isVisible(), `${route} has no visible shared header`)
    assert(await page.locator('main h1').isVisible(), `${route} has no visible primary content`)
    assert(await page.locator('footer').isVisible(), `${route} has no visible footer`)
    assert((await page.evaluate(() => [...document.styleSheets].filter(sheet => !sheet.disabled).length)) >= 2, `${route} is unstyled without JavaScript`)
  }
  assert.deepEqual(problems, [])
  await context.close()
})

await gate('all required viewports, languages and themes avoid horizontal overflow', async () => {
  for (const viewport of VIEWPORTS) {
    for (const locale of ['en', 'fr']) {
      for (const colorScheme of ['light', 'dark']) {
        const context = await browser.newContext({ viewport, colorScheme, reducedMotion: 'reduce' })
        const page = await context.newPage()
        const problems = watchPage(page)
        await page.goto(`${origin}/${locale}/`, { waitUntil: 'networkidle' })
        const geometry = await page.evaluate(() => {
          const viewportWidth = document.documentElement.clientWidth
          const critical = ['header', 'main', '#app', '.term', '#stage', '.faq', 'footer']
          const offenders = []
          for (const selector of critical) {
            for (const element of document.querySelectorAll(selector)) {
              const style = getComputedStyle(element)
              if (style.display === 'none' || style.visibility === 'hidden') continue
              const rect = element.getBoundingClientRect()
              if (rect.left < -1 || rect.right > viewportWidth + 1) {
                offenders.push(`${selector}:${rect.left.toFixed(1)}..${rect.right.toFixed(1)}`)
              }
            }
          }
          const moduleControls = [...document.querySelectorAll('#side [data-view]')].filter(element => {
            const style = getComputedStyle(element)
            const rect = element.getBoundingClientRect()
            return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0
          }).length
          return {
            viewportWidth,
            htmlWidth: document.documentElement.scrollWidth,
            bodyWidth: document.body.scrollWidth,
            offenders,
            moduleControls,
          }
        })
        const label = `${locale}/${colorScheme}/${viewport.width}x${viewport.height}`
        assert(geometry.htmlWidth <= geometry.viewportWidth + 1, `${label} html overflow ${geometry.htmlWidth} > ${geometry.viewportWidth}`)
        assert(geometry.bodyWidth <= geometry.viewportWidth + 1, `${label} body overflow ${geometry.bodyWidth} > ${geometry.viewportWidth}`)
        assert.deepEqual(geometry.offenders, [], `${label} clipped critical component(s)`)
        assert.equal(geometry.moduleControls, 6, `${label} does not expose all six app views`)
        assert.deepEqual(problems, [], `${label} emitted browser errors`)
        await context.close()
      }
    }
  }
})

await gate('information pages and 404 remain intact at every required viewport', async () => {
  for (const viewport of VIEWPORTS) {
    for (const colorScheme of ['light', 'dark']) {
      const context = await browser.newContext({ viewport, colorScheme, reducedMotion: 'reduce' })
      const page = await context.newPage()
      const problems = watchPage(page)
      for (const route of [...INFO_ROUTES, '/responsive-not-found']) {
        const response = await page.goto(`${origin}${route}`, { waitUntil: 'networkidle' })
        assert([200, 404].includes(response.status()))
        const geometry = await page.evaluate(() => ({
          viewportWidth: document.documentElement.clientWidth,
          htmlWidth: document.documentElement.scrollWidth,
          bodyWidth: document.body.scrollWidth,
          headerRight: document.querySelector('header')?.getBoundingClientRect().right ?? 0,
          footerRight: document.querySelector('footer')?.getBoundingClientRect().right ?? 0,
          hiddenHeading: !document.querySelector('main h1') || getComputedStyle(document.querySelector('main h1')).visibility === 'hidden',
        }))
        const label = `${route}/${colorScheme}/${viewport.width}x${viewport.height}`
        assert(geometry.htmlWidth <= geometry.viewportWidth + 1, `${label} html overflows by ${geometry.htmlWidth - geometry.viewportWidth}px`)
        assert(geometry.bodyWidth <= geometry.viewportWidth + 1, `${label} body overflows by ${geometry.bodyWidth - geometry.viewportWidth}px`)
        assert(geometry.headerRight <= geometry.viewportWidth + 1, `${label} header is clipped`)
        assert(geometry.footerRight <= geometry.viewportWidth + 1, `${label} footer is clipped`)
        assert.equal(geometry.hiddenHeading, false, `${label} primary heading is hidden`)
      }
      assert.deepEqual(problems, [], `${colorScheme}/${viewport.width} emitted browser errors`)
      await context.close()
    }
  }
})

await gate('200 percent zoom preserves navigation and legal reading order', async () => {
  // A 1280px display at 200% browser zoom exposes a 640px CSS viewport.
  const context = await browser.newContext({ viewport: { width: 640, height: 400 }, deviceScaleFactor: 2, reducedMotion: 'reduce' })
  const page = await context.newPage()
  for (const route of ['/en', '/privacy', '/support', '/legal', '/licenses', '/fr/legal']) {
    await page.goto(`${origin}${route}`, { waitUntil: 'networkidle' })
    const state = await page.evaluate(() => ({
      width: document.documentElement.scrollWidth,
      viewport: document.documentElement.clientWidth,
      skip: Boolean(document.querySelector('.skip')),
      main: Boolean(document.querySelector('main h1')),
      footer: Boolean(document.querySelector('footer')),
    }))
    assert(state.skip && state.main && state.footer, `${route} loses a landmark at 200% zoom`)
    assert(state.width <= state.viewport + 1, `${route} overflows horizontally at 200% zoom`)
  }
  await context.close()
})

await gate('legal pages expose a clean print document', async () => {
  const context = await browser.newContext({ reducedMotion: 'reduce' })
  const page = await context.newPage()
  await page.emulateMedia({ media: 'print' })
  for (const route of ['/legal', '/fr/legal']) {
    await page.goto(`${origin}${route}`, { waitUntil: 'networkidle' })
    const state = await page.evaluate(() => ({
      background: getComputedStyle(document.body).backgroundColor,
      color: getComputedStyle(document.body).color,
      header: getComputedStyle(document.querySelector('header')).display,
      footer: getComputedStyle(document.querySelector('footer')).display,
      sections: document.querySelectorAll('.legal-doc section').length,
      anchors: document.querySelectorAll('.doc-nav a[href^="#"]').length,
    }))
    assert(['rgb(255, 255, 255)', 'rgba(0, 0, 0, 0)'].includes(state.background))
    assert.equal(state.color, 'rgb(0, 0, 0)')
    assert.equal(state.header, 'none')
    assert.equal(state.footer, 'none')
    assert.equal(state.sections, 4)
    assert.equal(state.anchors, 4)
  }
  await context.close()
})

await gate('crawler finds no broken internal link or forbidden rendered URL', async () => {
  const result = await crawlSite({ browser, origin })
  assert.equal(result.routes.length, CANONICAL_ROUTES.length)
})

try {
  if (failures.length) {
    console.error(`\nSITE GATE FAILED — ${failures.length} of ${passes + failures.length} checks failed:`)
    failures.forEach(({ name, error }) => console.error(`- ${name}: ${error.message}`))
    process.exitCode = 1
  } else {
    console.log(`\nSITE GATE PASSED — ${passes} checks, isolated build ${externalOrigin ? 'and external target' : 'and route fixture'}.`)
  }
} finally {
  await browser.close()
  await fixture?.close()
  await build.cleanup()
}
