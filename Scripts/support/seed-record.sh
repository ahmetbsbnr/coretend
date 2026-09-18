#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Writes a store.sqlite holding a plausible safety-log trail, so the Record
# module can be captured in its loaded state. An empty screen proves nothing
# about a layout; this exists so the design is verified against the shape it
# actually has to hold.
#
# usage: seed-record.sh <store-dir>
set -euo pipefail
dir="${1:?usage: $0 <store-dir>}"
mkdir -p "$dir"
db="$dir/store.sqlite"
rm -f "$db"

now=$(date +%s)
sqlite3 "$db" <<SQL
-- Mirrors Store.migrate's own DDL. Seeding v1 and v2 as applied means the
-- app resumes at v3 and creates the rest itself, so this file only has to
-- know the one table it actually writes.
CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY, applied REAL NOT NULL);
CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE safety_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT NOT NULL,
    stage TEXT NOT NULL,
    redacted_path TEXT NOT NULL,
    rule_id TEXT NOT NULL,
    risk TEXT NOT NULL,
    size INTEGER NOT NULL DEFAULT 0,
    date REAL NOT NULL,
    result TEXT NOT NULL
);
CREATE INDEX idx_safety_log_date ON safety_log(date);
INSERT INTO schema_migrations VALUES (1, 0), (2, 0);
SQL

insert () { # operation stage path rule risk size ago result
  sqlite3 "$db" "INSERT INTO safety_log (operation_id,stage,redacted_path,rule_id,risk,size,date,result)
    VALUES ('$1','$2','$3','$4','$5',$6,$((now-$7)),'$8');"
}

# Today — a cleanup that moved a lot and declined a little.
insert dup-01 executed '<home>/Movies/Screen Recording 2026-04-02.mov' duplicate.exact low 1098000000 3600 'moved to Trash'
insert dup-01 executed '<home>/Pictures/Library/derivatives/3a91c/full.jpg' duplicate.exact low 221200000 3620 'moved to Trash'
insert dup-01 executed '<home>/Downloads/IMG_4821 (2).HEIC' duplicate.exact low 5033164 3640 'moved to Trash'
insert dup-01 executed '<home>/Downloads/archive-copy.zip' duplicate.exact low 84300000 3660 'moved to Trash'
insert dup-01 skipped '/System/Library/Caches/com.apple.kernelcaches' protected.sip high 0 3680 'protected by SIP'
insert dup-01 approved '<home>/Downloads/IMG_4821 (2).HEIC' duplicate.exact low 5033164 3700 'approved by user'

# Today — an operation that only refused. A first-class entry.
insert guard-02 skipped '<home>/Library/Mobile Documents/com~apple~CloudDocs' protected.icloud high 0 7200 'iCloud Drive, not a cache'
insert guard-02 skipped '<home>/Library/Keychains' protected.system high 0 7210 'system-critical location'

# Yesterday — an uninstall, plus one item that genuinely failed.
insert app-03 executed '/Applications/Figma.app' app.bundle medium 1203000000 90000 'moved to Trash'
insert app-03 executed '<home>/Library/Application Support/Figma' app.support low 41200000 90020 'moved to Trash'
insert app-03 error '<home>/Library/LaunchAgents/com.figma.agent.plist' app.launchagent medium 1204 90040 'permission denied'

# Three days ago — a large cleanup.
insert clutter-04 executed '<home>/Library/Caches/Google/Chrome' cache.browser low 780000000 260000 'moved to Trash'
insert clutter-04 executed '<home>/Library/Logs/DiagnosticReports' log.diagnostic low 122000000 260020 'moved to Trash'

echo "$db"
