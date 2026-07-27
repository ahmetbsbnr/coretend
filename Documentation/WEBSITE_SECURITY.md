# Website Security

Status: deployed; the generated configuration is also verified before every
production update.

## Attack surface

The site is static HTML/CSS with one local progressive-enhancement script, no
forms, cookies, backend, database, or processed user input. The script controls
the mobile navigation and visible-once scroll reveals; it performs no network
request and persists no data.

## HTTP response headers

- `Content-Security-Policy`: default/script/style/font/image/media sources are
  limited to self (plus data images); no external runtime origin is allowed.
- `Referrer-Policy: no-referrer` (or `strict-origin-when-cross-origin`).
- `Permissions-Policy`: deny geolocation, camera, microphone, and all
  other features not in use (i.e. all of them).
- `X-Content-Type-Options: nosniff`.

## Dependency surface

`generate.py` uses only the Python standard library (`os`). No npm/pip
dependencies to audit or patch.

## Reporting

Same channel as the app: see `SECURITY.md` at the repository root, which
routes reports to GitHub private vulnerability reporting at
`https://github.com/ahmetbsbnr/coretend/security/advisories/new`.
