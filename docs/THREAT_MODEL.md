# Threat model

What CoreTend is exposed to, what it defends against, and — more usefully —
what it does not. Written after finding two protected-root bypasses that had
been present since the first public commit, so it is grounded in defects this
project actually had rather than in a category checklist.

`.github/SECURITY.md` says how to report something. This says what is worth
reporting, and what the honest answer already is.

## What is at stake

**The user's files.** That is the whole list. CoreTend has no account, no
server, no stored credential, no user data of its own. It holds one SQLite
database in `~/Library/Application Support/CoreTend` containing scan results
and the Safety Log; both describe the user's own filesystem and never leave
the Mac.

Two things follow from that, and they shape everything below:

- The worst outcome is **a file moved that should not have been**, not a
  disclosure. CoreTend never deletes — everything eligible goes to the macOS
  Trash — so even the worst outcome is recoverable until the user empties it.
- The Safety Log is the only record that a file was touched. An attack that
  makes the log *wrong* is more serious than one that makes it *loud*.

## Where the boundaries are

CoreTend runs as the user, in the user's session, with whatever the user has
granted it — Full Disk Access on the Developer ID build, a sandbox with
user-selected scopes on the Mac App Store build. It is not privileged. It has
no helper tool, no daemon, no `setuid` anything, and it never asks for an
administrator password.

One network call exists in the entire source tree:

```sh
grep -rn URLSession Sources/          # one file: the update check
```

It is user-initiated, fetches a public JSON manifest, downloads nothing, and
opens the browser if there is something newer. There is no telemetry, no crash
reporting and no analytics, so there is also no channel through which a scan
result could leave the machine even by accident.

## What it defends against

### 1. Itself, acting on the wrong path

The largest realistic risk in a storage cleaner is its own logic. Every
destructive path goes through `SafetyCore.PathValidator`, never a raw
`FileManager` call on a user-supplied path, and the validator refuses:

| Refusal | Enforced by |
|---|---|
| anything outside the user's granted allowlist | `PathValidator` |
| a protected system root, however it is spelled | `PathValidator`, and the mutation suite |
| a path whose symlinks resolve into a protected root | `protectedRootSurvivesTheSymlinkedSystemAliases` |
| the home directory itself | `PathValidator` |
| an operation re-validated at execution time and no longer valid | `SafetyCenter`, `symlinkSwappedAfterApprovalRejected` |

Both 1.0.2 defects were in this layer, and both were the same shape: a check
that compared the path as *written* rather than as *meant*. Case folding on a
case-insensitive volume, and `/var` versus `/private/var`. Neither was
reported by anyone; both were found by auditing the rewrite.

### 2. A hostile filesystem

A scan reads directories the user points it at, and their contents are not
trusted input. Paths carry arbitrary bytes; a directory can be a symlink; a
file can be replaced between the moment it is shown and the moment it is
moved.

- **Symlinks** are resolved before validation, and the resolved path is
  checked as well as the literal one.
- **Time of check to time of use** is narrowed, not eliminated: every
  operation is validated again immediately before execution, and a path that
  changed in between is refused rather than acted on. The window between that
  second validation and the `trashItem` call is irreducible without kernel
  support, and this is stated rather than papered over. Exploiting it requires
  code already running as the user.
- **Paths are never interpolated into a shell.** There is no shell in the
  destructive path at all.

### 3. A tampered download

Every release is Developer ID signed, notarized by Apple, and stapled, so
Gatekeeper validates it without a network round trip. The checksums are
published and themselves signed with Minisign, and the Homebrew cask is
generated from the published release rather than typed, so a checksum that
stops matching the DMG fails a gate instead of reaching a user.

The release workflow builds from a clean checkout of an annotated tag on a
maintainer-controlled machine, refuses to publish when the tag and the
in-repo version disagree, verifies the artifacts *after downloading them back*
from the draft, and only then publishes.

**Zero runtime dependencies** is the largest security asset here.
`Package.resolved` holds the test framework and its own dependency, both
test-only. There is no supply chain to compromise at runtime because there is
no supply chain.

### 4. A record that quietly goes short

The Safety Log is append-only, and until 1.0.2 a failed write to it was
discarded: a file could reach the Trash with no record, in the product whose
thesis is that the record exists. The sink is still non-throwing by protocol —
an audit trail that can abort the operation it records is a worse problem than
a missing line — but the loss is now counted and stated beside the log's own
totals.

`purgeSafetyLog()` is the only deletion path, all-or-nothing, unrecoverable,
and user-initiated.

## What it does not defend against

Stated plainly, because a threat model that claims everything protects nobody.

- **Malware already running as the user.** Anything with the user's privileges
  can read the same files, move the same files, and edit CoreTend's database
  directly. CoreTend is not a security boundary against code that is already
  inside.
- **A compromised macOS, or an attacker with root.** The protected-root list
  is defence in depth *behind* System Integrity Protection, not a replacement
  for it. That is also why the 1.0.2 bypasses mattered less than their name
  suggests: the paths they reached are SIP-restricted and root-owned, so the
  operating system refused the operation regardless of what CoreTend decided.
- **Physical access, or an unlocked unattended Mac.**
- **A malicious build of CoreTend.** Verify the signature and the checksum;
  that is what they are for. Nothing inside a tampered app can be trusted to
  tell you it was tampered with.
- **The user deliberately pointing a scan at something they wanted to keep.**
  CoreTend shows every candidate with its evidence, preselects by risk, and
  requires an explicit confirmation — and then moves it to the Trash, which is
  where "I changed my mind" is answered.
- **Malware detection.** Integrity reports what macOS already recorded —
  download provenance, code-signature tier, login items. It is not an antivirus
  and the module says so in its own interface.

## Known residual risks

Kept here rather than in a private note, because the point of the document is
the part that is uncomfortable.

1. **The TOCTOU window described above.** Narrowed by re-validation, not
   closed.
2. **`SafetyCore` is at 80.4% line coverage**, and mutation testing showed
   that coverage overstates what is actually pinned: several lines were
   executed by tests that would have passed just as happily with the line
   inverted. Two of those were on the 1.0.2 fixes themselves and are now
   pinned; the rest are tracked on the `develop/v2` branch, where the tool
   and the 2.0 task queue live.
3. **The distinction between "moved to Trash" and "removed"** — which the
   Record shows to the user — is decided by one expression that no test
   currently pins, because forcing the branch needs a seam in `SafetyCenter`
   that does not exist yet. Named here so it is not discovered later as a
   surprise.
4. **The Mac App Store build is a different product** with a different
   boundary: sandboxed, with user-selected scopes, and three of eight
   destinations removed. When it ships, this document gains a section rather
   than a footnote.

## Reporting

Through GitHub private vulnerability reporting, per `.github/SECURITY.md`.
Please do not open a public issue.

If what you found is in the "does not defend against" list above, it is still
worth telling us — the list is a statement of the current boundary, not a
refusal to move it.
