# Website Privacy

Status: not deployed. This is a standing commitment for the site, checked
at every future deploy.

## No tracking, period

The site ships with, and must continue to ship with:

- No analytics of any kind (no Google Analytics, no Vercel Analytics, no
  Plausible, no self-hosted analytics).
- No advertising pixels or ad networks.
- No session replay / heatmap tools.
- No tracked third-party embeds (no autoloaded video, no social widgets).
- No marketing or preference cookies. No cookies at all, currently — the
  site sets none.
- No remote fonts (system font stack only) and no other unnecessary
  third-party requests.

## Data collected

None. There are no forms, no accounts, no newsletter signup, nothing that
collects visitor-submitted data.

## Server logs

Whatever host is eventually chosen will produce ordinary web server
access logs (IP, user agent, requested path) as an operational default of
that hosting platform, not something this project adds. This will be
documented concretely in `WEBSITE_DEPLOYMENT.md` once a host is chosen,
including retention and any opt-out.

## Relationship to the app's privacy stance

Consistent with the app itself: CoreTend the application has no
telemetry (see repo-root `PRIVACY.md`). The website extends the same
no-tracking commitment to the web presence.
