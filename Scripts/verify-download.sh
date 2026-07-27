#!/bin/zsh
# Verifies a downloaded file's SHA-256 against an expected checksum.
# Never executes the file. Usage:
#   Scripts/verify-download.sh <file> <expected-sha256>
set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <file> <expected-sha256>"
  exit 2
fi

FILE="$1"
EXPECTED="$2"

if [ ! -f "$FILE" ]; then
  echo "verify-download.sh: FAILED — file not found: $FILE"
  exit 1
fi

ACTUAL=$(shasum -a 256 "$FILE" | awk '{print $1}')
EXPECTED_LOWER=$(echo "$EXPECTED" | tr '[:upper:]' '[:lower:]')

if [ "$ACTUAL" = "$EXPECTED_LOWER" ]; then
  echo "OK: $FILE matches expected SHA-256 ($ACTUAL)"
  exit 0
else
  echo "MISMATCH: $FILE"
  echo "  expected: $EXPECTED_LOWER"
  echo "  actual:   $ACTUAL"
  echo "Do not open this file — re-download from the official source and verify again."
  exit 1
fi
