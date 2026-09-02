# Public-site gates

These scripts build the site into a fresh temporary directory, serve it with
the checked-in Vercel redirects and rewrites, and test the public URL contract.
They never serve `Website/` as a raw directory.

```sh
npm install --no-save playwright pngjs
npx playwright install chromium
node Scripts/site/test-site.mjs
node Scripts/site/crawl-site.mjs
node Scripts/site/route-map.mjs
node Scripts/visual/capture.mjs
```

`SITE_BASE_URL=https://… node Scripts/site/test-site.mjs` runs the browser and
HTTP gates against a deployed preview or production while still verifying a
fresh local build. `VISUAL_BASE_URL` provides the equivalent visual target.

Visual references are never accepted automatically:

- `node Scripts/visual/capture.mjs --capture-only` writes review PNGs without
  changing `Scripts/visual/reference.json`;
- `node Scripts/visual/capture.mjs --update` is the explicit, review-required
  action which replaces fingerprints;
- the default command compares current captures with reviewed fingerprints.

The public-output scan rejects technical URLs, local hosts and personal home
paths. `/Users/demo/...` is deliberately allowed because it is the documented,
versioned fictional identity used by CoreTend's product fixtures.
