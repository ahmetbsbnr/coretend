#!/usr/bin/env node
/** Print an evidence-ready map of canonical routes and historical redirects. */
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildSite, startSite } from './site-fixture.mjs'
import { CANONICAL_ROUTES } from './crawl-site.mjs'

const HISTORICAL = [
  '/index.html', '/en', '/fr', '/en/index.html', '/fr/index.html',
  '/privacy.html', '/support.html', '/legal.html', '/licenses.html',
  '/site', '/site/', '/site/index.html',
  '/Website', '/Website/', '/Website/index.html',
  '/en.html', '/fr.html',
]
const NOT_FOUND = ['/en/obsolete.html', '/fr/obsolete.html', '/route-map-not-found']
const SOURCE = {
  '/': 'index.html', '/en/': 'en-route.html', '/fr/': 'fr-route.html',
  '/privacy': 'privacy.html', '/support': 'support.html', '/legal': 'legal.html',
  '/licenses': 'licenses.html',
}

function extract(document, expression) {
  return document.match(expression)?.[1] ?? ''
}

async function inspect(origin, route) {
  const response = await fetch(`${origin}${route}`, { redirect: 'manual' })
  const location = response.headers.get('location') ?? ''
  const target = location ? new URL(location, origin) : null
  const destination = target
    ? (target.origin === origin
        ? `https://coretend.ahmetbsbnr.com${target.pathname}${target.search}${target.hash}`
        : target.href)
    : ''
  const document = response.status === 200 || response.status === 404 ? await response.text() : ''
  return {
    route,
    status: response.status,
    canonical: extract(document, /<link\s+rel=["']canonical["']\s+href=["']([^"']+)/i),
    language: extract(document, /<html\b[^>]*\blang=["']([^"']+)/i),
    source: SOURCE[route] ?? (response.status === 404 ? '404.html' : 'redirect rule'),
    destination,
  }
}

async function main() {
  const build = process.env.SITE_BASE_URL ? null : await buildSite()
  const fixture = build ? await startSite(build.output) : null
  const origin = process.env.SITE_BASE_URL?.replace(/\/$/, '') ?? fixture.origin
  try {
    const routes = [...CANONICAL_ROUTES, '/download', ...HISTORICAL, ...NOT_FOUND]
    const records = []
    for (const route of routes) records.push(await inspect(origin, route))
    if (process.argv.includes('--json')) {
      console.log(JSON.stringify({ origin, routes: records }, null, 2))
    } else {
      console.log('| URL | HTTP | Canonical | Lang | Source | Redirect destination |')
      console.log('|---|---:|---|---|---|---|')
      for (const record of records) {
        console.log(`| ${record.route} | ${record.status} | ${record.canonical || '—'} | ${record.language || '—'} | ${record.source} | ${record.destination || '—'} |`)
      }
    }
  } finally {
    await fixture?.close()
    await build?.cleanup()
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main()
}
