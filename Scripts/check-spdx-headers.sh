#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: The CoreTend Authors
#
# Every Swift file under Sources/ and Tests/ must open with the two-line
# SPDX header — the same machine-readable licence provenance the shell and
# Python scripts already carry. New files that skip it fail here.
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

expect_id='// SPDX-License-Identifier: Apache-2.0'
expect_copy='// SPDX-FileCopyrightText: The CoreTend Authors'
missing=0
checked=0

for f in $(find Sources Tests -name '*.swift' | sort); do
  checked=$((checked + 1))
  line1=$(sed -n '1p' "$f")
  line2=$(sed -n '2p' "$f")
  if [ "$line1" != "$expect_id" ] || [ "$line2" != "$expect_copy" ]; then
    echo "FAIL: missing/incorrect SPDX header: $f"
    missing=$((missing + 1))
  fi
done

if [ "$missing" -ne 0 ]; then
  echo
  echo "check-spdx-headers.sh: $missing of $checked Swift files lack the header."
  echo "Prepend these two lines (then a blank line) to each:"
  echo "  $expect_id"
  echo "  $expect_copy"
  exit 1
fi

echo "check-spdx-headers.sh: OK ($checked Swift files carry the SPDX header)"
