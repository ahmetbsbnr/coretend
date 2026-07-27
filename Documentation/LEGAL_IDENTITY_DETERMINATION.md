<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Legal Identity Determination

**Date:** 2026-07-27
**Scope:** what the CoreTend site publishes about who runs it, and why.
**This is not legal advice.** It is a written record of a reasoned choice, made
so the choice is auditable and so nobody later has to guess at the reasoning.

## 1. The prior question: is this launch professional?

Everything downstream depends on this, so it is answered first, against the
criteria the launch brief sets out. Each is a factual claim about the product as
it actually ships, verifiable in the repository:

| Criterion | State | Evidence |
|---|---|---|
| Any price | None | No payment path exists in the app or site |
| Any sale | None | Nothing is sold |
| Any subscription | None | No account, no billing, no entitlement code |
| Any donation | None | No donation link, no sponsor button |
| Any advertising | None | No ad slot, no ad network, no sponsored content |
| Any affiliate link | None | No outbound monetised link |
| Any commercial activity tied to the software | None | — |
| Any user account | None | `accountRequired: false`; the app has no sign-in |
| Any commercial data collection | None | `telemetry: false`; no analytics, no pixels, no session replay |

**Determination: non-professional.** CoreTend is a free, open-source personal
project. It is published by an individual, not by an undertaking, and no economic
activity is attached to it.

### What would overturn this

This determination is not permanent. It stops being true the moment any of the
following happens, and the legal pages must be revisited **before** that ships:

- a paid tier, licence fee, or any price of any kind;
- a donation or sponsorship link;
- advertising or affiliate revenue;
- a user account system;
- any data collection for commercial purposes;
- distribution through a paid channel, including the Mac App Store.

If any of those arrive, the site becomes a professional publication and the
notice must then carry the publisher's full identity and address, plus (in
France) a SIREN if the activity is registered. **None of that may be invented.**
Production must be blocked until the real values exist.

## 2. What the site publishes

| Field | Value | Why |
|---|---|---|
| Publisher | `Ahmet (@ahmetbsbnr) — ahmetbsbnr.com` | Exactly what the owner already publishes about themselves on their own public GitHub profile (given name), plus the handle they own and the domain the site runs on. Identifiable and verifiable. |
| Status | Individual, non-professional | §1 above |
| Address | **Not published** | See §3 |
| Contact | GitHub private vulnerability reporting | See §4 |
| Host | Vercel Inc., 440 N Barranca Ave #4133, Covina, CA 91723, USA | See §5 |
| Publication director | Same as publisher | Same natural person; there is no separate editorial structure |

### What was deliberately not done

**No surname was published.** The owner's public GitHub profile shows the given
name "Ahmet" and no surname. A surname could have been guessed from the local
filesystem path on the build machine, but a filesystem path is not a
self-identification — inferring identity from it and publishing the result would
be inventing personal data, which the launch brief forbids and which is not the
agent's call to make. If the owner wants a full legal name on the notice, they
set `publisherOfRecord` in `Configuration/PublicIdentity.local.json` and
regenerate; nothing else needs to change.

**No company, SIREN, VAT number, or phone number was invented.** None exists, so
none is claimed.

## 3. Why the address is withheld

French law (LCEN, Article 6 III-2) allows a person publishing a site **in a
non-professional capacity** to withhold their name and address from the public,
provided they have supplied that identity to their host, and provided the host's
own details are published. That is precisely the arrangement here: the identity
sits with Vercel via the account, and Vercel's legal address is on the notice.

This is the mechanism that exists for personal sites, and using it is not a
loophole — publishing a private individual's home address on a public website
carries a real safety cost and no corresponding benefit to any user of a free
open-source utility. The launch brief independently forbids publishing the
owner's personal address.

The legal page states the withholding and its basis openly rather than leaving a
blank row, so a reader can see that the omission is deliberate and lawful rather
than an oversight.

## 4. Security contact

No email address was invented. The contact is the **GitHub private vulnerability
reporting** channel on the public repository — a real, monitored, private intake
route that exists without publishing a personal inbox.

It is only written into `PublicIdentity.local.json` once all three hold:

1. the repository exists;
2. private vulnerability reporting is enabled on it;
3. the "Report a vulnerability" page has been confirmed reachable.

Until then `securityContact` stays as `[SECURITY_CONTACT_TO_DEFINE]`, which
renders literally on the site and keeps `Scripts/check-placeholders.sh` blocking
a production deploy. The gate is what stops a reassuring-looking security page
from shipping over a contact route that does not actually work.

## 5. Host details

Taken from Vercel's own Terms of Service (`vercel.com/legal/terms`, retrieved
2026-07-27), which names this address for service of legal notice:

```
Vercel Inc.
440 N Barranca Ave #4133
Covina, CA 91723
United States
https://vercel.com
```

This is public corporate information published by the host about itself, not
personal data, so it lives in the tracked `PublicIdentity.example.json` rather
than the gitignored local file.

## 6. How this is wired

`Website/generate.py` reads `Configuration/PublicIdentity.example.json`, then
overlays `Configuration/PublicIdentity.local.json` key by key. The local file is
gitignored, so real identity values are never committed.

Two properties of the design matter more than the values themselves:

1. **An undefined value renders as its literal `[SOMETHING_TO_DEFINE]` token**
   inside a `placeholder-token` span, so `Scripts/check-placeholders.sh` finds it
   and blocks production. The site cannot quietly ship with an undefined
   publisher or security contact.
2. **The pending-values warning banner is derived, not flagged.** It appears
   while either the publisher or the security contact is still a token, and
   disappears on its own when both are real. There is no separate switch anyone
   has to remember to flip, and therefore no way to leave a stale "these are
   placeholders" banner on a finished page, or to remove the banner while
   placeholders remain.

Before this change the generator hardcoded the placeholder strings and read no
configuration at all — `PublicIdentity` was documented in fifteen files but
consumed by nothing. Filling it in would have had no effect on the site.
