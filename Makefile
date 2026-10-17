# CoreTend — build and check from source.
#   make build   the app and the command-line tool
#   make test    the test suite
#   make check   build, tests, safety audit and site checks (what CI runs)
#   make app     an unsigned CoreTend.app in Artifacts/
#   make site    regenerate the website in Website/

PY_TARGETS = generate-manifest build-site site-check safety-audit test-cli-interrupt
.PHONY: python-version build test check app site package-local $(PY_TARGETS)

# The scripts use Python 3.10 syntax; macOS ships an older python3 in /usr/bin.
python-version:
	@python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null || { \
	  echo "CoreTend scripts need Python 3.10 or newer as python3; found: $$(python3 --version 2>&1 || echo none)." >&2; \
	  echo "On macOS, put a newer Python first in PATH, e.g. export PATH=/opt/homebrew/bin:\$$PATH" >&2; \
	  exit 1; }

$(PY_TARGETS): python-version

build:
	swift build --product CoreTendApp
	swift build --product CoreTendCLI

test:
	swift test

generate-manifest:
	python3 Scripts/generate_manifest.py

build-site:
	python3 Scripts/build_site.py

site: generate-manifest build-site

site-check:
	python3 -B -m unittest Scripts.test_site_accessibility_contract
	python3 Scripts/check_site.py

safety-audit:
	python3 Scripts/audit_safety.py

test-cli-interrupt: build
	python3 Scripts/test_cli_interrupt.py .build/debug/CoreTendCLI

check: site site-check safety-audit test test-cli-interrupt

app package-local:
	bash Scripts/package_local.sh

# Maintainer targets (release, captures, audits), kept out of the public repository.
-include dev.mk
