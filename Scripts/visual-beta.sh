#!/bin/zsh
# Launches CoreTend against a deterministic Visual Beta scenario.
#
# The scenario changes the data source only: the same production views render
# it. There is no alternate "preview" application, by design — a screenshot of
# a preview proves nothing about the app that ships.
#
# usage: visual-beta.sh <scenario> [module] [light|dark] [compact|standard|large]
set -euo pipefail
cd "$(dirname "$0")/.."

scenario="${1:?usage: $0 <scenario> [module] [light|dark] [compact|standard|large]}"
module="${2:-}"
appearance="${3:-dark}"
size="${4:-standard}"

# The store override is validated by TestStoreOverride and refused unless it
# sits under a temporary root, so this path is not a free choice.
store="${TMPDIR:-/tmp}/coretend-visual-beta/$scenario"
rm -rf "$store"; mkdir -p "$store"

# pkill, not `tell application to quit`: `open -n` starts a *new* instance
# each time, so quitting "the" application leaves every earlier one running.
# Two live instances is how a capture ended up photographing another
# instance's window geometry and returning a rectangle of desktop.
pkill -x CoreTend 2>/dev/null || true
sleep 1

# `env` rather than a `${var:+NAME=value}` prefix: under zsh that expands to a
# single word and is looked up as a command, which fails with
# "command not found: CORETEND_TEST_MODULE=Record".
env CORETEND_TEST_MODE=1 \
    CORETEND_TEST_STORE_DIR="$store" \
    CORETEND_FIXTURE="$scenario" \
    CORETEND_TEST_APPEARANCE="$appearance" \
    CORETEND_TEST_WINDOW="$size" \
    ${module:+CORETEND_TEST_MODULE="$module"} \
    open -n build/CoreTend.app >/dev/null

print "Visual Beta: $scenario · ${module:-default} · $appearance · $size"
print "store: $store"
