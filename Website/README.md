# Website (dev notes)

Static, bilingual (en/fr) site for CoreTend. Plain HTML/CSS, one
generator script, no framework, no backend, no database, no analytics.

## Build

```
cd Website
python3 generate.py
```

Regenerates `en/*.html` and `fr/*.html` from the content tables in
`generate.py`. Output is committed static HTML — there is no separate
"production build" step; the generated files are what gets served.

## Local preview

```
cd Website
python3 -m http.server 8791
# open http://localhost:8791/en/index.html
```

## Known placeholders — must not ship to production

- The homepage screenshot uses a labeled `.screenshot-placeholder` box, not
  a real screenshot (this dev environment has no attached display to
  capture one). Replace with a real screenshot before any production
  deploy.
- Legal/contact/domain values (`[LEGAL_NAME_TO_DEFINE]`,
  `[LEGAL_ADDRESS_TO_DEFINE]`, `[SECURITY_CONTACT_TO_DEFINE]`,
  `[DOMAIN_TO_DEFINE]`, `[HOST_TO_DEFINE]`, `[REPO_URL_TO_DEFINE]`,
  `[LICENSE_SPDX_TO_CONFIRM]`) are bracket placeholders tracked in
  `Documentation/HUMAN_BLOCKERS.md`. `Scripts/check-placeholders.sh`
  should be extended to scan `Website/` too before any real publish.
- The Download page intentionally shows no real release artifact.

See `Documentation/WEBSITE_ARCHITECTURE.md`, `WEBSITE_SECURITY.md`,
`WEBSITE_PRIVACY.md`, and `WEBSITE_DEPLOYMENT.md` for the rest.
