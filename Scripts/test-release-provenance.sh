#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Tests for the release-provenance design (Documentation/RELEASE_PROVENANCE.md).
#
# These run against throwaway git repositories in temp directories, never
# against the real one: they need to create tags, dirty trees and bad templates,
# none of which may happen to the repository being audited. The real ZIP/DMG
# build is stubbed out — what is under test is the provenance logic, not
# packaging, which Scripts/test-distribution.sh already covers.
set -eu
cd "$(dirname "$0")/.."
REPO_ROOT=$(pwd)

pass=0
fail=0
ok()   { echo "PASS: $1"; pass=$((pass + 1)); }
nope() { echo "FAIL: $1"; fail=$((fail + 1)); }

# Builds a throwaway repo containing build-release.sh, a template, and stub
# packaging scripts that produce fake artifacts.
make_repo() {
  root=$(mktemp -d)
  mkdir -p "$root/Scripts" "$root/Release/Notes" "$root/Configuration"

  cp "$REPO_ROOT/Scripts/build-release.sh" "$root/Scripts/"
  cp "$REPO_ROOT/Release/latest.template.json" "$root/Release/"

  cat > "$root/Configuration/PublicIdentity.example.json" <<'EOF'
{ "marketingVersion": "9.9.9" }
EOF

  # Stubs: create plausible artifacts without a Swift toolchain.
  cat > "$root/Scripts/package-zip.sh" <<'EOF'
#!/bin/sh
mkdir -p Release
printf 'fake-zip-%s' "$1" > "Release/CoreTend-$1-arm64-unsigned.zip"
EOF
  cat > "$root/Scripts/package-dmg.sh" <<'EOF'
#!/bin/sh
mkdir -p Release
printf 'fake-dmg-%s' "$1" > "Release/CoreTend-$1-arm64-unsigned.dmg"
EOF
  chmod +x "$root/Scripts/package-zip.sh" "$root/Scripts/package-dmg.sh"

  printf 'notes\n' > "$root/Release/Notes/9.9.9.en.md"
  printf 'dist/\nRelease/latest.json\nRelease/SHA256SUMS\n*.zip\n*.dmg\n' > "$root/.gitignore"

  git -C "$root" init -q
  git -C "$root" config user.email "test@example.invalid"
  git -C "$root" config user.name "Provenance Test"
  git -C "$root" add -A
  git -C "$root" commit -qm "initial"
  echo "$root"
}

manifest_field() {
  /usr/bin/python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get(sys.argv[2]))" "$1" "$2"
}

# 1 — clean tree, no tag: builds and records honest provenance
R=$(make_repo)
if (cd "$R" && zsh Scripts/build-release.sh 9.9.9 >/dev/null 2>&1); then
  HEAD_SHA=$(git -C "$R" rev-parse HEAD)
  if [ "$(manifest_field "$R/dist/latest.json" sourceCommit)" = "$HEAD_SHA" ]; then
    ok "sourceCommit records the commit that was packaged"
  else
    nope "sourceCommit should equal the built commit"
  fi
  [ "$(manifest_field "$R/dist/latest.json" treeState)" = "clean" ] \
    && ok "treeState is clean on a clean tree" || nope "treeState should be clean"
  [ "$(manifest_field "$R/dist/latest.json" releaseTag)" = "None" ] \
    && ok "releaseTag is null on an untagged build" || nope "releaseTag should be null when untagged"
  [ "$(manifest_field "$R/dist/latest.json" releasable)" = "True" ] \
    && ok "releasable is true from a clean tree" || nope "releasable should be true"
  [ -n "$(manifest_field "$R/dist/latest.json" buildInvocationID)" ] \
    && ok "buildInvocationID is recorded" || nope "buildInvocationID missing"
else
  nope "a clean-tree build should succeed"
fi
rm -rf "$R"

# 2 — the manifest is not tracked, and building does not dirty the tree
R=$(make_repo)
(cd "$R" && zsh Scripts/build-release.sh 9.9.9 >/dev/null 2>&1) || true
if [ -z "$(git -C "$R" status --short)" ]; then
  ok "building leaves the tree clean (nothing generated is tracked)"
else
  nope "building dirtied the tree:"; git -C "$R" status --short | sed 's/^/    /'
fi
rm -rf "$R"

# 3 — a dirty tree is refused
R=$(make_repo)
printf 'dirty\n' >> "$R/Release/Notes/9.9.9.en.md"
if (cd "$R" && zsh Scripts/build-release.sh 9.9.9 >/dev/null 2>&1); then
  nope "a dirty-tree build should be refused"
else
  ok "a dirty tree is refused"
fi
rm -rf "$R"

# 4 — ALLOW_DIRTY_BUILD marks the build non-releasable rather than lying
R=$(make_repo)
printf 'dirty\n' >> "$R/Release/Notes/9.9.9.en.md"
if (cd "$R" && ALLOW_DIRTY_BUILD=1 zsh Scripts/build-release.sh 9.9.9 >/dev/null 2>&1); then
  [ "$(manifest_field "$R/dist/latest.json" treeState)" = "dirty" ] \
    && ok "ALLOW_DIRTY_BUILD records treeState=dirty" || nope "treeState should be dirty"
  [ "$(manifest_field "$R/dist/latest.json" releasable)" = "False" ] \
    && ok "a dirty build is marked releasable=false" || nope "releasable should be false"
else
  nope "ALLOW_DIRTY_BUILD=1 should permit a local build"
fi
rm -rf "$R"

# 5 — a tagged build records the tag, and the tag points at sourceCommit
R=$(make_repo)
git -C "$R" tag -a v9.9.9 -m "test tag"
if (cd "$R" && zsh Scripts/build-release.sh 9.9.9 >/dev/null 2>&1); then
  [ "$(manifest_field "$R/dist/latest.json" releaseTag)" = "v9.9.9" ] \
    && ok "releaseTag records the exact tag at HEAD" || nope "releaseTag should be v9.9.9"
  TAG_SHA=$(git -C "$R" rev-parse "refs/tags/v9.9.9^{commit}")
  [ "$(manifest_field "$R/dist/latest.json" sourceCommit)" = "$TAG_SHA" ] \
    && ok "the tag points at sourceCommit" || nope "tag and sourceCommit should agree"
else
  nope "a tagged clean build should succeed"
fi
rm -rf "$R"

# 6 — a tag that is an ancestor, not exactly at HEAD, is not claimed
R=$(make_repo)
git -C "$R" tag -a v9.9.8 -m "older tag"
printf 'more\n' >> "$R/Release/Notes/9.9.9.en.md"
git -C "$R" add -A && git -C "$R" commit -qm "later commit"
if (cd "$R" && zsh Scripts/build-release.sh 9.9.9 >/dev/null 2>&1); then
  [ "$(manifest_field "$R/dist/latest.json" releaseTag)" = "None" ] \
    && ok "an ancestor tag is not claimed as the release tag" \
    || nope "releaseTag should be null when HEAD is not exactly tagged"
else
  nope "build should succeed with an ancestor tag"
fi
rm -rf "$R"

# 7 — a template carrying a computed field fails the build
R=$(make_repo)
/usr/bin/python3 - "$R/Release/latest.template.json" <<'PY'
import json, sys
p = sys.argv[1]
t = json.load(open(p))
t["zipSHA256"] = "deadbeef"          # a hand-edited checksum must never win
json.dump(t, open(p, "w"), indent=2)
PY
git -C "$R" add -A && git -C "$R" commit -qm "poison template"
if (cd "$R" && zsh Scripts/build-release.sh 9.9.9 >/dev/null 2>&1); then
  nope "a template containing a computed field should fail the build"
else
  ok "a hand-edited computed field in the template fails the build"
fi
rm -rf "$R"

# 8 — checksums actually verify
R=$(make_repo)
(cd "$R" && zsh Scripts/build-release.sh 9.9.9 >/dev/null 2>&1) || true
if (cd "$R/dist" && shasum -a 256 -c SHA256SUMS >/dev/null 2>&1); then
  ok "generated SHA256SUMS verifies against the generated files"
else
  nope "generated SHA256SUMS should verify"
fi
rm -rf "$R"

# 9 — a missing template is a hard failure, not a silent default
R=$(make_repo)
git -C "$R" rm -q "Release/latest.template.json"
git -C "$R" commit -qm "remove template"
if (cd "$R" && zsh Scripts/build-release.sh 9.9.9 >/dev/null 2>&1); then
  nope "a missing template should fail the build"
else
  ok "a missing template fails the build"
fi
rm -rf "$R"

echo
echo "release provenance tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
echo "All release-provenance tests passed."
