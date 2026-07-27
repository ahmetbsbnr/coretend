#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Tests for Scripts/check-test-isolation.sh. A gate nobody tests is a gate that
# silently stops gating: this proves it actually fails on each thing it claims to
# catch, not just that it passes on the real tree.
set -eu
cd "$(dirname "$0")/.."
GATE="$(pwd)/Scripts/check-test-isolation.sh"

pass=0
fail=0
ok()   { echo "PASS: $1"; pass=$((pass + 1)); }
nope() { echo "FAIL: $1"; fail=$((fail + 1)); }

# Builds a minimal fake tree containing only what the gate inspects.
make_tree() {
  root=$(mktemp -d)
  mkdir -p "$root/Sources/Persistence" "$root/Sources/CoreTendApp" "$root/Scripts"

  cat > "$root/Sources/Persistence/TestStoreOverride.swift" <<'EOF'
public enum TestStoreOverride {
    public static let markerKey = "CORETEND_TEST_MODE"
    public static let pathKey = "CORETEND_TEST_STORE_DIR"
    public enum Rejection { case markerNotExactlyOne(String), pathNotAbsolute(String)
        case pathNotUnderTemporaryRoot(String), pathProtected(String)
        case pathIsHomeOrAbove(String), pathEmpty }
    public static func isTestMarkerSet(environment: [String: String]) -> Bool { false }
}
EOF

  cat > "$root/Sources/Persistence/Store.swift" <<'EOF'
public actor Store {
    public static func defaultPath() throws -> String {
        if let o = TestStoreOverride.current.directory { return o.path }
        return try userPath()
    }
    public static func userPath() throws -> String { "" }
    public static func userDirectory() throws -> URL { URL(fileURLWithPath: "/") }
}
EOF

  cat > "$root/Sources/CoreTendApp/AppEnvironment.swift" <<'EOF'
private static func runLegacyMigration() -> Report? {
    guard !TestStoreOverride.isTestMarkerSet(environment: ProcessInfo.processInfo.environment)
    else { return nil }
}
EOF

  cat > "$root/Scripts/test-distribution.sh" <<'EOF'
fingerprint_real_store() { find "$REAL_STORE_DIR" -type f; }
BEFORE_FP=$(fingerprint_real_store)
CORETEND_TEST_MODE=1 CORETEND_TEST_STORE_DIR="$TEST_STORE_DIR" \
  open -W -n -a "$APP" --args --smoke-test-quit-immediately &
AFTER_FP=$(fingerprint_real_store)
if [ "$BEFORE_FP" = "$AFTER_FP" ]; then echo ok; fi
if [ -f "$TEST_STORE_DIR/migration-log.json" ]; then echo bad; fi
EOF

  cp "$GATE" "$root/Scripts/check-test-isolation.sh"
  echo "$root"
}

run_gate() { CHECK_TEST_ISOLATION_ROOT="$1" sh "$GATE" >"$1/out.txt" 2>&1; }

# 1 — the happy path
T=$(make_tree)
if run_gate "$T"; then ok "a correctly isolated tree passes"; else
  nope "a correctly isolated tree should pass"; cat "$T/out.txt"; fi
rm -rf "$T"

# 2 — override source deleted entirely
T=$(make_tree); rm "$T/Sources/Persistence/TestStoreOverride.swift"
if run_gate "$T"; then nope "a tree with no override source should fail"; else
  ok "removing the override source blocks the gate"; fi
rm -rf "$T"

# 3 — single-key override (the dangerous regression)
T=$(make_tree)
sed -i '' 's/public static let pathKey = "CORETEND_TEST_STORE_DIR"/public static let pathKey = "X"/' \
  "$T/Sources/Persistence/TestStoreOverride.swift"
if run_gate "$T"; then nope "a single-key override should fail"; else
  ok "dropping one of the two required variables blocks the gate"; fi
rm -rf "$T"

# 4 — a validation rule removed
T=$(make_tree)
sed -i '' 's/pathProtected(String)//' "$T/Sources/Persistence/TestStoreOverride.swift"
if run_gate "$T"; then nope "removing the protected-root rule should fail"; else
  ok "removing a validation rule blocks the gate"; fi
rm -rf "$T"

# 5 — Store stops consulting the override
T=$(make_tree)
sed -i '' 's/TestStoreOverride.current.directory/nil/' "$T/Sources/Persistence/Store.swift"
if run_gate "$T"; then nope "a Store that ignores the override should fail"; else
  ok "a Store that stops consulting the override blocks the gate"; fi
rm -rf "$T"

# 6 — migration suppression removed (would copy real data into the temp store)
T=$(make_tree)
sed -i '' 's/isTestMarkerSet/somethingElse/' "$T/Sources/CoreTendApp/AppEnvironment.swift"
if run_gate "$T"; then nope "unsuppressed migration should fail"; else
  ok "removing migration suppression blocks the gate"; fi
rm -rf "$T"

# 7 — a launch with no isolation variables
T=$(make_tree)
cat > "$T/Scripts/test-distribution.sh" <<'EOF'
fingerprint_real_store() { find "$REAL_STORE_DIR" -type f; }
BEFORE_FP=$(fingerprint_real_store)
open -W -n -a "$APP" --args --smoke-test-quit-immediately &
AFTER_FP=$(fingerprint_real_store)
if [ "$BEFORE_FP" = "$AFTER_FP" ]; then echo ok; fi
if [ -f "$TEST_STORE_DIR/migration-log.json" ]; then echo bad; fi
EOF
if run_gate "$T"; then nope "an unisolated launch should fail"; else
  ok "launching without the isolation variables blocks the gate"; fi
rm -rf "$T"

# 8 — fingerprint comparison removed from the dynamic test
T=$(make_tree)
sed -i '' 's/if \[ "\$BEFORE_FP" = "\$AFTER_FP" \]; then echo ok; fi//' \
  "$T/Scripts/test-distribution.sh"
if run_gate "$T"; then nope "a test that never compares fingerprints should fail"; else
  ok "removing the fingerprint comparison blocks the gate"; fi
rm -rf "$T"

# 9 — a script that mutates the real store
T=$(make_tree)
printf 'rm -rf "$HOME/Library/Application Support/CoreTend"\n' > "$T/Scripts/naughty.sh"
if run_gate "$T"; then nope "a script mutating the real store should fail"; else
  ok "a script that mutates the real store blocks the gate"; fi
rm -rf "$T"

echo
echo "check-test-isolation.sh tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
echo "All check-test-isolation.sh tests passed."
