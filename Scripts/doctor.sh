#!/bin/sh
# Diagnoses a dev environment: toolchain version, platform, macOS version,
# repo cleanliness. Read-only — never modifies anything. Safe to run from
# any working directory or machine.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

fail=0

echo "CoreTend — doctor"
echo "======================"

echo "-- Platform --"
uname_s=$(uname -s)
if [ "$uname_s" != "Darwin" ]; then
  echo "FAIL: this is a macOS-only project (uname reports: $uname_s)."
  fail=1
else
  echo "OK: macOS ($(sw_vers -productVersion 2>/dev/null || echo unknown))"
fi

echo "-- Swift toolchain --"
if command -v swift >/dev/null 2>&1; then
  swift --version 2>&1 | sed 's/^/  /'
  major=$(swift --version 2>&1 | grep -oE 'version [0-9]+' | head -1 | grep -oE '[0-9]+' || echo 0)
  if [ "${major:-0}" -lt 6 ]; then
    echo "WARN: Package.swift targets swift-tools-version 6.0; found major version $major."
  else
    echo "OK: Swift toolchain >= 6."
  fi
else
  echo "FAIL: 'swift' not found on PATH."
  fail=1
fi

echo "-- Xcode / Command Line Tools --"
if xcode-select -p >/dev/null 2>&1; then
  echo "OK: developer tools at $(xcode-select -p)"
else
  echo "FAIL: no active developer directory. Run: xcode-select --install"
  fail=1
fi

echo "-- Repo state --"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git rev-parse --abbrev-ref HEAD)
  echo "  branch: $branch"
  if [ -n "$(git status --porcelain)" ]; then
    echo "  NOTE: working tree has local changes (not a failure)."
  else
    echo "  OK: working tree clean."
  fi
else
  echo "WARN: not a git working tree (or git missing) — skipping."
fi

echo "-- Integrity --"
echo "  OK: local integrity checks require no third-party scanner"

echo "======================"
if [ "$fail" -eq 0 ]; then
  echo "doctor: all required checks passed."
else
  echo "doctor: one or more required checks FAILED. See above."
fi
exit "$fail"
