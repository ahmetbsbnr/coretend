#!/usr/bin/env node
/**
 * Isolated build and HTTP fixture for CoreTend's public site.
 *
 * The server intentionally models the checked-in Vercel redirects and
 * rewrites instead of exposing the build directory as a raw file tree. This
 * keeps local browser gates honest about the public URL contract.
 */
import { spawn } from 'node:child_process'
import { createReadStream } from 'node:fs'
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises'
import { createServer } from 'node:http'
import { tmpdir } from 'node:os'
import { dirname, extname, join, normalize, resolve, sep } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
export const repoRoot = resolve(here, '..', '..')

const TYPES = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.mp4': 'video/mp4',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.txt': 'text/plain; charset=utf-8',
  '.vtt': 'text/vtt; charset=utf-8',
  '.webm': 'video/webm',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.webp': 'image/webp',
  '.woff2': 'font/woff2',
  '.xml': 'application/xml; charset=utf-8',
}

function run(command, args, options = {}) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, {
      cwd: repoRoot,
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
      ...options,
    })
    let stdout = ''
    let stderr = ''
    child.stdout?.on('data', chunk => { stdout += chunk })
    child.stderr?.on('data', chunk => { stderr += chunk })
    child.once('error', reject)
    child.once('close', code => {
      if (code === 0) resolvePromise({ stdout, stderr })
      else reject(new Error(`${command} exited ${code}\n${stdout}${stderr}`))
    })
  })
}

/** Build to a new temporary directory. Nothing under Website/dist is reused. */
export async function buildSite() {
  const temporaryRoot = await mkdtemp(join(tmpdir(), 'coretend-site-gate-'))
  const output = join(temporaryRoot, 'dist')
  try {
    const result = await run('python3', ['Website/build.py', '--output', output])
    return {
      output,
      log: `${result.stdout}${result.stderr}`.trim(),
      async cleanup() { await rm(temporaryRoot, { recursive: true, force: true }) },
    }
  } catch (error) {
    await rm(temporaryRoot, { recursive: true, force: true })
    throw error
  }
}

function compileSource(source) {
  const names = []
  const escaped = source
    .replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    .replace(/:([A-Za-z][A-Za-z0-9_]*)/g, (_, name) => {
      names.push(name)
      return '([^/]+)'
    })
  return { expression: new RegExp(`^${escaped}$`), names }
}

function matchRule(pathname, rule) {
  const compiled = compileSource(rule.source)
  const match = pathname.match(compiled.expression)
  if (!match) return null
  let destination = rule.destination
  compiled.names.forEach((name, index) => {
    destination = destination.replace(`:${name}`, match[index + 1])
  })
  return destination
}

function localFile(buildDirectory, publicPath) {
  let decoded
  try { decoded = decodeURIComponent(publicPath) } catch { return null }
  if (decoded.includes('\0')) return null
  const relative = normalize(decoded).replace(/^[/\\]+/, '')
  const candidate = resolve(buildDirectory, relative || 'index.html')
  const root = resolve(buildDirectory)
  if (candidate !== root && !candidate.startsWith(root + sep)) return null
  return candidate
}

function addConfiguredHeaders(headers, pathname, config) {
  for (const entry of config.headers ?? []) {
    const source = entry.source
    let matches = false
    if (source === '/(.*)') matches = true
    else if (source === '/assets/(.*)') matches = pathname.startsWith('/assets/')
    else if (source === '/(latest.json|SHA256SUMS)') {
      matches = pathname === '/latest.json' || pathname === '/SHA256SUMS'
    }
    if (!matches) continue
    for (const header of entry.headers ?? []) headers[header.key] = header.value
  }
}

/** Start a server which applies the repository's redirects before rewrites. */
export async function startSite(buildDirectory, options = {}) {
  const configPath = options.configPath ?? join(repoRoot, 'vercel.json')
  const config = JSON.parse(await readFile(configPath, 'utf8'))
  const redirects = config.redirects ?? []
  const rewrites = config.rewrites ?? []

  const server = createServer(async (request, response) => {
    const method = request.method ?? 'GET'
    let url
    try { url = new URL(request.url ?? '/', 'http://fixture.invalid') } catch {
      response.writeHead(400).end('bad request')
      return
    }
    const pathname = url.pathname

    // Vercel applies its trailing-slash normalization before custom redirects
    // and rewrites. Model that ordering so local gates cannot accept a URL
    // contract that adds redirects after deployment.
    if (config.trailingSlash === false && pathname.length > 1 && pathname.endsWith('/')) {
      response.writeHead(308, {
        location: `${pathname.replace(/\/+$/, '')}${url.search}`,
        'cache-control': 'no-store',
      }).end()
      return
    }

    for (const rule of redirects) {
      const destination = matchRule(pathname, rule)
      if (!destination) continue
      response.writeHead(rule.permanent ? 308 : 307, {
        location: destination,
        'cache-control': 'no-store',
      }).end()
      return
    }

    let rewritten = pathname
    for (const rule of rewrites) {
      const destination = matchRule(pathname, rule)
      if (destination) { rewritten = destination; break }
    }

    let file = localFile(buildDirectory, rewritten)
    let statusCode = 200
    try {
      const details = file ? await stat(file) : null
      if (details?.isDirectory()) file = join(file, 'index.html')
      if (!file || !(await stat(file)).isFile()) throw new Error('not a file')
    } catch {
      statusCode = 404
      file = join(buildDirectory, '404.html')
    }

    try {
      const details = await stat(file)
      const headers = {
        'content-type': TYPES[extname(file)] ?? 'application/octet-stream',
        'content-length': String(details.size),
      }
      addConfiguredHeaders(headers, pathname, config)
      response.writeHead(statusCode, headers)
      if (method === 'HEAD') response.end()
      else createReadStream(file).pipe(response)
    } catch {
      response.writeHead(500, { 'content-type': 'text/plain; charset=utf-8' }).end('fixture error')
    }
  })

  await new Promise((resolvePromise, reject) => {
    server.once('error', reject)
    server.listen(options.port ?? 0, options.host ?? '127.0.0.1', resolvePromise)
  })
  const address = server.address()
  const origin = `http://${options.host ?? '127.0.0.1'}:${address.port}`
  return {
    config,
    origin,
    server,
    async close() { await new Promise(resolvePromise => server.close(resolvePromise)) },
  }
}

/**
 * Resolve Playwright both in CI (repository node_modules) and in the adjacent
 * portfolio checkout used by the shared local workspace. The fallback is
 * relative and contains no account-specific path.
 */
export async function loadPlaywright() {
  try { return await import('playwright') } catch (primaryError) {
    const configured = process.env.CORETEND_NODE_MODULES
    const candidates = [
      configured,
      resolve(repoRoot, '..', '..', '..', 'ahmetbsbnr-portfolio', 'node_modules'),
    ].filter(Boolean)
    for (const modules of candidates) {
      try {
        return await import(pathToFileURL(join(modules, 'playwright', 'index.mjs')).href)
      } catch {}
    }
    throw new Error(
      `Playwright is required. Run "npm install --no-save playwright". (${primaryError.message})`
    )
  }
}

/** Prefer Playwright's pinned Chromium; use installed stable Chrome locally. */
export async function launchChromium(chromium) {
  const channel = process.env.CORETEND_BROWSER_CHANNEL
  if (channel) return chromium.launch({ channel })
  try { return await chromium.launch() } catch (error) {
    if (!/Executable doesn't exist/.test(error.message)) throw error
    return chromium.launch({ channel: 'chrome' })
  }
}

async function commandLine() {
  const build = await buildSite()
  const fixture = await startSite(build.output, {
    port: process.env.PORT ? Number(process.env.PORT) : 4173,
    host: process.env.HOST ?? '127.0.0.1',
  })
  process.stdout.write(`${build.log}\nCoreTend route fixture: ${fixture.origin}\n`)
  const stop = async () => {
    await fixture.close()
    await build.cleanup()
    process.exit(0)
  }
  process.once('SIGINT', stop)
  process.once('SIGTERM', stop)
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await commandLine()
}
