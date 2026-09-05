<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# CoreTend website — server-side environment

These variables power the Contact / Community API (`Website/api/*`). Set them
in **Vercel → Project `coretend` → Settings → Environment Variables**. Never
put them in a committed file, and never in client-side or generated JS. A
plain `.env` is gitignored; there is no `.env` in the repo by design.

Copy the block below into Vercel (values filled in from the providers):

```
# Database — Vercel Postgres (Neon). Auto-populated once the store is created
# and linked to the project; scripts/migrate.mjs reads POSTGRES_URL.
POSTGRES_URL=

# Transactional email — Resend. Create an API key after verifying the sending
# domain ahmetbsbnr.com (see COMMUNITY_CONTACT_HANDOFF.md → EXTERNAL
# CONFIGURATION REQUIRED).
RESEND_API_KEY=

# Moderation admin. Long random secret; gates /api/admin/community via
# `Authorization: Bearer <ADMIN_TOKEN>`.  Generate: openssl rand -hex 32
ADMIN_TOKEN=

# Optional. Extra salt for the per-IP rate-limit key hash (any random string;
# changing it only resets buckets). Defaults to a fixed per-endpoint string.
RATE_SALT=

# Optional. Canonical origin used in email links. Defaults to the prod URL.
SITE_ORIGIN=https://coretend.ahmetbsbnr.com
```

## Notes

- `node --test test/` runs the whole API test suite with **none** of these
  set — every handler takes an injected `deps` (fake store, fake mailer,
  fixed clock).
- `node scripts/migrate.mjs --dry-run` needs nothing; the real run needs
  `POSTGRES_URL`.
- `RESEND_API_KEY` is read only in `api/_lib/mail.js`, server-side. If it is
  unset in production the API still validates, persists, and returns `202
  { mailed:false }` rather than 500 — the message is saved, just not
  forwarded until the key is added.
