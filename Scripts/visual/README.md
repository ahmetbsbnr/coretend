# Visual regression

`capture.mjs` builds the publish-only site and captures 51 deterministic views:

- EN and FR, light and dark, at 1440×900, 1280×800, 1024×768,
  820×1180, 430×932, 390×844 and 360×800;
- root without JavaScript plus privacy, support, legal, licenses and branded 404
  at desktop and mobile sizes;
- official, initialization, orbit, hover and focus logo states;
- compact header, stabilized footer, scanning, paused, completed and mobile
  Reduce Motion states.

Run the comparison after installing Playwright and `pngjs`:

```sh
node Scripts/visual/capture.mjs
```

Reference acceptance is intentionally a separate review action. First create
PNG evidence without changing truth:

```sh
node Scripts/visual/capture.mjs --capture-only
```

Review `Scripts/visual/output/`, including the targeted logo and simulation
states. Only after that review may the baseline be replaced explicitly:

```sh
node Scripts/visual/capture.mjs --update
git diff -- Scripts/visual/reference.json
node Scripts/visual/capture.mjs
```

The default command never updates `reference.json` after a failure. Generated
PNGs are evidence/artifacts, not committed source assets.
