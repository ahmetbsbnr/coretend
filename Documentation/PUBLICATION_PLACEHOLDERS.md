# Publication Placeholders

Centralized list of literal placeholder tokens used throughout the repo
and website for information that must be supplied by a human before
public release (see HUMAN_BLOCKERS.md for why each needs a human).

`Scripts/check-placeholders.sh` greps for these tokens; a nonzero count
before a real release is expected and intentional — it is a release
*gate*, not a bug.

| Placeholder | Appears in | Meaning |
|---|---|---|
| `[SECURITY_CONTACT_TO_DEFINE]` | SECURITY.md, CODE_OF_CONDUCT.md | Real security/conduct-report contact needed |
| `[MAINTAINER_HANDLE_TO_DEFINE]` | NOTICE, `.github/CODEOWNERS` | Real GitHub maintainer handle needed |
| `[REPO_URL_TO_DEFINE]` | various docs | Final public repository URL |
| `[LEGAL_NAME_TO_DEFINE]` | Website legal pages | Real legal/publisher name |
| `[LEGAL_ADDRESS_TO_DEFINE]` | Website legal pages | Real legal address |
| `[DOMAIN_TO_DEFINE]` | Website config/docs | Final production domain |

Do not replace these with invented values. Leave them as literal tokens
until a human supplies the real value.
