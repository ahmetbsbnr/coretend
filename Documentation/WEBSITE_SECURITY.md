# Website Security

Status: not deployed. This documents the intended posture for when a human
decides to deploy — nothing here is live yet.

## Attack surface

The site is static HTML/CSS with no JavaScript logic, no forms, no
cookies, no backend, no database, no user input processed anywhere. This
keeps the attack surface close to zero by construction — there is no
server-side code to exploit and no user-submitted data to sanitize.

## Planned HTTP response headers (once deployed)

Not live yet — to be configured at the hosting layer when a deploy target
is chosen:

- `Content-Security-Policy`: default-src 'self'; no external script/style/
  font/image origins, since none are used.
- `Referrer-Policy: no-referrer` (or `strict-origin-when-cross-origin`).
- `Permissions-Policy`: deny geolocation, camera, microphone, and all
  other features not in use (i.e. all of them).
- `X-Content-Type-Options: nosniff`.

## Dependency surface

`generate.py` uses only the Python standard library (`os`). No npm/pip
dependencies to audit or patch.

## Reporting

Same channel as the app: see `SECURITY.md` at the repository root
(`[SECURITY_CONTACT_TO_DEFINE]` until a monitored channel exists).
