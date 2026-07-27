# Publication Placeholders

Record of the literal placeholder tokens this repository used for
information that had to be supplied by a human before public release, and
what each one resolved to.

Tokens are written here **without their brackets**. The bracketed form is
what `Scripts/check-placeholders.sh` and `Scripts/check-publish-readiness.sh`
grep for, so spelling it out in this document would make the registry
itself block the release it exists to describe.

## Status: all resolved

Every token below now has a real value. None was invented; where a value
is deliberately withheld, that is stated rather than filled with a
plausible substitute.

| Token | Was needed for | Resolved to |
|---|---|---|
| `SECURITY_CONTACT_TO_DEFINE` | SECURITY.md, CODE_OF_CONDUCT.md | GitHub private vulnerability reporting: `github.com/ahmetbsbnr/coretend/security/advisories/new`. Verified live 2026-07-27. No email address was invented. |
| `MAINTAINER_HANDLE_TO_DEFINE` | NOTICE, `.github/CODEOWNERS` | `ahmetbsbnr` |
| `REPO_URL_TO_DEFINE` | various docs | `https://github.com/ahmetbsbnr/coretend` — public since the 0.9.0 launch phase |
| `LEGAL_NAME_TO_DEFINE` | Website legal pages | `publisherOfRecord` in `Configuration/PublicIdentity.local.json`: the given name the owner already publishes on their own GitHub, plus their handle and domain. **No surname was inferred** from the filesystem path or any local metadata. |
| `LEGAL_ADDRESS_TO_DEFINE` | Website legal pages | **Deliberately withheld.** `legalAddress` is `null`. Under LCEN Art. 6 III-2 a non-professional publisher may withhold their personal address provided the host holds their identity; Vercel Inc. does, via the account. The site states this openly rather than hiding the omission. See `LEGAL_IDENTITY_DETERMINATION.md`. |
| `DOMAIN_TO_DEFINE` | Website config/docs | `coretend.ahmetbsbnr.com` (configured; DNS and deployment status tracked in `RELEASE_STATE.md`) |

## The mechanism is still armed

Resolving these values did not remove the safety net.

`Configuration/PublicIdentity.example.json` still carries bracketed tokens
as its defaults, and it is the only file excluded from the placeholder
scan — deliberately, because those defaults *are* the failure mode. If the
gitignored `Configuration/PublicIdentity.local.json` is missing or
incomplete, `Website/generate.py` falls back to the example file and the
site renders literal tokens inside a placeholder-token span. That is
intended behaviour, not a bug.

Three independent checks keep it honest:

1. `check-publish-readiness.sh` requires `PublicIdentity.local.json` to
   exist and to contain no `_TO_DEFINE` value — stricter than a text scan.
2. It separately requires `securityContact` to be set.
3. Generated site HTML is tracked and still scanned, so an identity
   regression that reached a regenerated page would be caught.

Do not replace a token with an invented value. If a real value is not
available, leave the token literal and let the gate block.
