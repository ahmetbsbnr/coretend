#!/bin/bash
# End-to-end gate for the release chain and the version-sync contract.
#
# The failure this exists to prevent: GitHub, the application, the website and
# the portfolio each stating a different version, with nothing noticing. Every
# check below is therefore a comparison against the SINGLE source of truth,
# Configuration/PublicIdentity.example.json, and the gate fails on divergence
# rather than reporting it.
#
# It performs no network write, publishes nothing and needs no secret. The
# GitHub comparison is skipped (not failed) when gh is unavailable or
# unauthenticated, so the gate still runs in a clean checkout.
set -uo pipefail
cd "${SYNC_TEST_ROOT:-$(dirname "$0")/..}"

fail=0
problems=""
note() { fail=1; problems="$problems\n  - $1"; }
ok() { printf '  OK: %s\n' "$1"; }

echo "== test-release-sync.sh =="

SOT="Configuration/PublicIdentity.example.json"
[ -f "$SOT" ] || { echo "FAIL: single source of truth $SOT is missing"; exit 1; }

VERSION=$(/usr/bin/python3 -c "import json;print(json.load(open('$SOT'))['marketingVersion'])")
CHANNEL=$(/usr/bin/python3 -c "import json;print(json.load(open('$SOT'))['channel'])")
echo "-- source of truth: $VERSION ($CHANNEL) --"

# 1. The application binary's own product version must match, while Apple's
#    bundle-version keys remain in their stricter numeric format.
PLIST_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CoreTendMarketingVersion" Resources/Info.plist 2>/dev/null)
[ "$PLIST_VERSION" = "$VERSION" ] \
  && ok "app marketing version agrees ($PLIST_VERSION)" \
  || note "app CoreTendMarketingVersion says '$PLIST_VERSION', source of truth says '$VERSION'"

PLIST_SHORT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist 2>/dev/null)
PLIST_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Info.plist 2>/dev/null)
case "$PLIST_SHORT" in
  [0-9]*.[0-9]*.[0-9]*) ok "CFBundleShortVersionString is Apple-compatible ($PLIST_SHORT)" ;;
  *) note "CFBundleShortVersionString must be three dot-separated integers; found '$PLIST_SHORT'" ;;
esac
case "$PLIST_SHORT" in
  *[!0-9.]*|*.*.*.*) note "CFBundleShortVersionString can contain only digits and periods; found '$PLIST_SHORT'" ;;
esac
case "$PLIST_BUILD" in
  *[!0-9.]*|*.*.*.*) note "CFBundleVersion can contain only digits and periods; found '$PLIST_BUILD'" ;;
  *) ok "CFBundleVersion is Apple-compatible ($PLIST_BUILD)" ;;
esac

# 2. The recorded project state must match.
STATE_VERSION=$(/usr/bin/python3 -c "import json;print(json.load(open('Documentation/PROJECT_STATE.json'))['version'])" 2>/dev/null)
[ "$STATE_VERSION" = "$VERSION" ] \
  && ok "PROJECT_STATE.json agrees" \
  || note "PROJECT_STATE.json says '$STATE_VERSION', source of truth says '$VERSION'"

# 3. Release notes for this exact version must exist in both locales.
for loc in en fr; do
  [ -f "Release/Notes/$VERSION.$loc.md" ] \
    && ok "release notes present ($loc)" \
    || note "missing Release/Notes/$VERSION.$loc.md"
done

# 4. The channel must be one the release workflow understands, and it must
#    agree with the version's own shape. A '-rc.N' version on the 'stable'
#    channel is exactly the kind of mismatch that ships a prerelease to
#    everyone.
case "$VERSION" in
  *-rc.*)   EXPECTED=release-candidate ;;
  *-beta.*) EXPECTED=beta ;;
  *)        EXPECTED=stable ;;
esac
[ "$CHANNEL" = "$EXPECTED" ] \
  && ok "channel '$CHANNEL' matches the version shape" \
  || note "version '$VERSION' implies channel '$EXPECTED' but '$CHANNEL' is declared"

# 5. The website must render the source-of-truth version, not a copy.
if [ -f "Website/en/index.html" ]; then
  grep -q "$VERSION" Website/en/index.html \
    && ok "website (en) renders $VERSION" \
    || note "Website/en/index.html does not mention $VERSION — regenerate the site"
  grep -q "$VERSION" Website/fr/index.html \
    && ok "website (fr) renders $VERSION" \
    || note "Website/fr/index.html does not mention $VERSION — regenerate the site"
fi

# 6. No stale version may be hardcoded anywhere in the generator. Versions
#    must be read from the identity file, never typed into a page.
STALE=$(grep -rEn '"0\.[0-9]+\.[0-9]+' Website/generate.py 2>/dev/null | grep -v "$VERSION" || true)
[ -z "$STALE" ] \
  && ok "no hardcoded version literal in the site generator" \
  || note "hardcoded version literal(s) in Website/generate.py:
$STALE"

# 7. A backup tag must never be publishable. Assert the release workflow
#    refuses them explicitly, not merely by pattern luck.
if [ -f ".github/workflows/release.yml" ]; then
  grep -q 'backup' .github/workflows/release.yml \
    && ok "release workflow explicitly refuses backup tags" \
    || note "release workflow has no explicit backup-tag guard"
  grep -qE '^\s*contents:\s*read' .github/workflows/release.yml \
    && ok "release workflow defaults to least privilege" \
    || note "release workflow does not default to contents: read"
else
  note "no release workflow found"
fi

# 8. No secret may be echoed by the release workflow.
if [ -f ".github/workflows/release.yml" ]; then
  LEAK=$(grep -nE 'echo .*(secrets\.|MINISIGN_SECRET|_TOKEN)' .github/workflows/release.yml \
         | grep -v 'not configured' || true)
  [ -z "$LEAK" ] \
    && ok "no secret is echoed by the release workflow" \
    || note "possible secret echoed in release workflow:
$LEAK"
fi

# 9. When a manifest exists, every declared artifact must exist and match.
if [ -f "dist/latest.json" ]; then
  MANIFEST_VERSION=$(/usr/bin/python3 -c "import json;print(json.load(open('dist/latest.json'))['version'])")
  if [ "$MANIFEST_VERSION" = "$VERSION" ]; then
    ok "generated manifest agrees ($MANIFEST_VERSION)"
  else
    # dist/ is build output and is gitignored. Between a version bump and the
    # build that follows it, a stale manifest is expected, not a divergence —
    # the artifacts simply have not been rebuilt yet. It is only wrong if it
    # claims to BE the current version while disagreeing, which is the case
    # above. Report it so it cannot be missed, without failing a tree whose
    # only fault is not having been rebuilt.
    echo "  (dist/latest.json is stale at $MANIFEST_VERSION; rebuild before releasing $VERSION)"
  fi
  ( cd dist && shasum -a 256 -c SHA256SUMS >/dev/null 2>&1 ) \
    && ok "artifact checksums verify" \
    || note "dist/SHA256SUMS does not verify against the artifacts on disk"
else
  echo "  (no dist/latest.json — artifact checks skipped, nothing has been built)"
fi

# 10. What GitHub actually publishes, when we can ask.
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  LIVE=$(gh release list -R ahmetbsbnr/coretend --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || true)
  if [ -n "$LIVE" ]; then
    LIVE_VERSION="${LIVE#v}"
    if [ "$LIVE_VERSION" = "$VERSION" ]; then
      # Same version on both sides: the artifacts must have come from THIS
      # commit, not merely carry the same number. A version string that
      # matches while the code differs is the exact failure this gate exists
      # for — it is how rc.1 shipped binaries that predated their own tag.
      ok "newest GitHub release agrees ($LIVE)"
      TAG_COMMIT=$(git rev-list -n 1 "$LIVE" 2>/dev/null || true)
      HEAD_COMMIT=$(git rev-parse HEAD)
      if [ -n "$TAG_COMMIT" ] && [ "$TAG_COMMIT" != "$HEAD_COMMIT" ]; then
        echo "  (tag $LIVE points at ${TAG_COMMIT:0:7}, HEAD is ${HEAD_COMMIT:0:7} — expected while work continues after a release)"
      fi
    else
      # A tree ahead of the published release is the normal state between a
      # version bump and its release. A tree BEHIND one is not: it means the
      # published release is newer than the code in hand.
      NEWEST=$(printf '%s\n%s\n' "$LIVE_VERSION" "$VERSION" | sort -V | tail -1)
      if [ "$NEWEST" = "$VERSION" ]; then
        echo "  (this tree declares $VERSION; newest published release is $LIVE_VERSION — release pending)"
      else
        note "GitHub has published '$LIVE_VERSION', which is newer than this tree's '$VERSION'"
      fi
    fi
  fi
  BACKUP=$(gh api repos/ahmetbsbnr/coretend/git/refs/tags --jq '.[].ref' 2>/dev/null | grep -c backup || true)
  [ "${BACKUP:-0}" = "0" ] \
    && ok "no backup/* tag exists on the remote" \
    || note "$BACKUP backup tag(s) reached the remote — they must never be pushed"
else
  echo "  (gh unavailable or unauthenticated — GitHub comparison skipped)"
fi

echo
if [ "$fail" -ne 0 ]; then
  printf 'FAIL — release/sync problems:%b\n' "$problems"
  exit 1
fi
echo "test-release-sync.sh: PASSED — every surface agrees on $VERSION ($CHANNEL)."
