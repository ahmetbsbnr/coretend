# CoreTend rc.4 delivery status

Last verified: 2026-08-02 (Europe/Istanbul)

This is the durable delivery journal for `v0.9.1-rc.4`. It distinguishes a
locally validated candidate from a published release. Until the tagged GitHub
asset has been downloaded and independently verified, the public release record
and `/download` intentionally remain on `v0.9.1-rc.3`.

## Recovery checkpoint

- Repository: workspace-relative `products/coretend/app`
- Release branch: `release/v0.9.1-rc.4`
- Branch base and recovered `origin/main`: `fb76c47d47ca6f544063a5de713a9c30245beb25`
- Recovered local/remote release HEAD: `87e035e`
- Existing release commits: `b5f84e2` and `87e035e`
- Pull request: GitHub PR #5
- Recovered worktree change: the canonical `Website/index.html` contained the
  under-900px `.flow-sticky { position: static; top: auto; }` correction that
  prevents the bilingual Workflow steps from scrolling behind their heading.
  It was backed up before any further edit and retained in the canonical
  template, not copied into a generated output.
- No `v0.9.1-rc.4` branch collision, public tag, GitHub Release or public rc.4
  asset existed at recovery time.

## Verified recovery backups

| Scope | Archive | SHA-256 | Contents and verification |
| --- | --- | --- | --- |
| Interrupted CoreTend state | `_backups/coretend-interrupted-20260802T070612Z.tar.gz` | `447159ba457588785b696d12a00c765a533c7adfb4725fcbab2fa4595ce99ca4` | Full Git bundle, `git bundle verify` output, state, tracked patch, useful working-tree files and restore instructions |
| Portfolio pre-rc.4 state | `_backups/portfolio-pre-rc4-20260802T071550Z.tar.gz` | `3a9076d6ec1dff127db0f8dde62d2b346c87282e8a24be63f410bcce526e82fe` | Full Git bundle, `git bundle verify` output, state, patch and restore instructions |

The archives are independent of any stash. Final post-delivery bundles will be
created only after both public repositories and production are verified.

## Release-branch commits

- `b5f84e2` — correct documentation and Markdown links
- `87e035e` — exclude explicit `/Users/demo/...` fixtures from private-data
  findings without weakening the Security gate
- `d06e689` — complete the shared public-site shell and reviewed visual matrix;
  preserve the mobile Workflow fix; remove the hard-coded Support rc.3 value
- `54a9e65` — prepare rc.4 identity, build 914 and bilingual release notes
- `23bb09c` — harden locale selection and isolate Xcode test storage
- `076056b` — isolate Integrity data sources in test mode
- `1c707fb` — strip release debug/source-path records before signing and scan
  the packaged Mach-O for private checkout/build-account paths
- `01ecf29` — isolate application inventory during test-mode capture
- `fe1f599` — add a two-key-guarded test-only appearance override for honest
  light/dark artifact capture

## Public website gate

`Website/index.html` and `Website/build.py` are the canonical source and
generator. Generated `dist/` output is not edited by hand.

- The Workflow overlap on `/en`, `/fr` and narrow/mobile viewports is fixed in
  the canonical template and covered by a regression assertion.
- Support no longer contains `Version 0.9.1-rc.3`; the home, Support,
  installation/download UI, `latest.json` and `SHA256SUMS` all receive release
  facts from the canonical release record at build time.
- The shared shell covers `/`, `/en`, `/fr`, `/privacy`, `/support`, `/legal`,
  `/licenses`, the installation surface and the real 404: shared header and
  footer, independent logo arcs around a fixed core, Paper/Ink/Cobalt living
  backgrounds, theme/language controls, focus states, reading progress,
  offscreen/page-hidden animation suspension and reduced-motion fallback.
- Privacy, Support, Legal, Licenses and 404 use route-specific measurement and
  radar variants; none is a raw generic document page.
- Canonical/hreflang/x-default, Open Graph, sitemap, robots, manifests, clean
  locale URLs, direct refresh, no-JavaScript content and real 404 status are
  gated.
- Transparent, versioned favicon assets are present at SVG, ICO, 16, 32, Apple
  touch 180, manifest 192 and manifest 512 sizes.
- Thirty-two behavioral/accessibility/release assertions pass.
- Seventy-nine deliberately selected baseline captures were reviewed and
  committed across required routes, desktop/mobile, English/French,
  light/dark and reduced motion. The suite checks the required viewport matrix,
  200% zoom, horizontal overflow, console errors, Axe, keyboard focus, print
  styles, no-JavaScript output and the logo's independent-arc contract.

The generator still emits rc.3 release facts for public output at this
checkpoint. This is intentional: public metadata is not promoted from a local
candidate.

## Application and local candidate gate

The exact locally validated candidate was built from clean release-branch HEAD
`fe1f599f24b6fa68e1abc5d7f7e010d29c6641f9` with
`Scripts/build-release.sh 0.9.1-rc.4`.

| Field | Verified value |
| --- | --- |
| DMG | `Release/CoreTend-0.9.1-rc.4-arm64-unsigned.dmg` |
| Local size | `4,795,244` bytes |
| Local SHA-256 | `2aafe32bdb052f1133a39438fd9a677008b083eef78f749bf0311cf73a848863` |
| Source commit | `fe1f599f24b6fa68e1abc5d7f7e010d29c6641f9` |
| Tree state recorded by manifest | `clean` |
| Marketing version | `0.9.1-rc.4` |
| Bundle version | `0.9.1` (`CFBundleShortVersionString`), build `914` |
| Bundle identifier | `com.ahmetbsbnr.coretend` |
| Architecture | `arm64` |
| Localizations | `Base.lproj`, `fr.lproj` |
| Signature | ad hoc; `codesign --verify --deep --strict` passed |
| Gatekeeper | `spctl` rejected with exit 3, expected without Developer ID/notarization |

Evidence is preserved under
`_backups/coretend-rc4-candidate-fe1f599/`. `hdiutil imageinfo` and
`hdiutil verify` pass. The image mounted read-only twice and detached cleanly
twice; the volume contains `CoreTend.app` and an `/Applications` symlink. The
app was copied into an isolated Applications directory and launched with
`CORETEND_TEST_MODE=1` and a temporary store; it remained alive beyond the
smoke-test interval and exited normally when the harness ended.

The exact extracted app was captured on Dashboard, Storage, Space Lens,
Duplicates, Applications, Integrity, Activity and Settings in English/dark
and French/light. Test-mode resolvers restricted Applications and Integrity to
validated temporary fixture roots, so the captures contain no real machine
inventory, download or login-item data. Pause, resume and cancel controls are
also exercised by the Swift behavior suite.

Raw bundle and Mach-O scans report no `ClamAV`, `clamscan` or `MalwareEngine`,
no checkout or `/Users/<build-account>/` path, no common private-key or token
signature and no debug object/module archive. `IntegrityCore`/Integrity strings
and the rendered Integrity destination are present.

This local DMG is a validation candidate, not yet the public asset. The tagged
workflow will build again from the final merge/tag commit; only that downloaded
asset's size and checksum may be promoted to the public release record.

## `hdiutil` diagnosis and correction

The earlier mount/conversion failure was real rather than hidden: the affected
sandboxed process returned `Périphérique non configuré`, and verbose output
reported `Cannot start hdiejectd because app is sandboxed`. In an earlier
conversion attempt that broken device lifecycle also left an invalid image.

The release path now runs on an unsandboxed macOS host or clean macOS Actions
runner and generates the Finder metadata deterministically through pinned
`dmgbuild`/`ds_store` tooling. It does not launch Finder, AppleScript or require
an Automation/TCC grant. The 600×400 and 1200×800 background representations,
window bounds, icon locations and Applications link are inspected by the
headless layout test. Repeated local imageinfo/verify/mount/detach cycles and the
CI packaging job pass with this method.

## Test evidence at the pre-publication checkpoint

| Gate | Result |
| --- | --- |
| Swift Debug build | passed |
| Swift Release build | passed |
| Swift package suite | 338 passed; no regression from the recovered 329 |
| Xcode build/test | passed on the candidate lineage |
| Distribution check | passed against a newly packaged app and isolated user store |
| DMG layout/headless/provenance/manifest/checksum gates | passed |
| Localizations | 561/561 entries and resources passed |
| Repository doctor, feature inventory, secret/private-data/path scans | passed |
| Markdown links | passed |
| Website route/accessibility/visual gate | 32 behavioral checks and 79 reviewed baselines passed |
| PR Security and distribution checks | passed on `fe1f599`; final checks must rerun after this journal commit |

Nine test skips are explicit rather than silent: eight `XCUIApplication`
contracts cannot launch an app because SwiftPM emits that target as a unit-test
bundle, and the Developer ID assertion skips because this unsigned delivery has
no Apple signing identity. The exact extracted DMG app is nevertheless launched
and visually exercised by the isolated artifact harness. No skipped test is
reported as executed.

## Release notes and installation truth

`Release/Notes/0.9.1-rc.4.en.md` and `.fr.md` state that rc.4 supersedes rc.3
without replacing its files, removes the former ClamAV wrapper and replaces its
surface with first-party read-only Integrity checks, remains ad-hoc signed and
not notarized, and is not currently in the Mac App Store. The supported route
is copy to Applications, attempt launch, then System Settings → Privacy &
Security → Open Anyway. The project never disables Gatekeeper or removes
quarantine automatically. Developer ID signing and notarization remain future
distribution work.

## Gates still open at this checkpoint

- Commit and push this corrected journal, then obtain all PR #5 checks on its
  newest SHA.
- Merge PR #5 into `main` without rewriting history; verify CI, Security and
  Vercel on the merge commit.
- Tag that exact commit `v0.9.1-rc.4`; let the macOS release workflow build and
  publish its fresh artifacts.
- Download the public DMG and re-run checksum, size, image, mount, bundle,
  private-data, ClamAV/Integrity and launch gates against that exact asset.
- Only after that verification, atomically promote the canonical public release
  record, generated site, `/download`, README/CHANGELOG/install documentation
  and portfolio; deploy and verify production.
- Create and verify final Git bundles after both repositories are clean and
  equal to their remotes.

The only intended distribution limitations after those gates are Developer ID
signing, Apple notarization and a possible future Mac App Store study.
