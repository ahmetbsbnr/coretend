.PHONY: test build generate-manifest build-site site-check traceability safety-audit qualify package-local verify-package

test:
	swift test

build:
	swift build --product CoreTendApp
	swift build --product CoreTendCLI

generate-manifest:
	python3 Scripts/generate_manifest.py

build-site:
	python3 Scripts/build_site.py

site-check:
	python3 Scripts/check_site.py

traceability:
	python3 Scripts/check_traceability.py

safety-audit:
	python3 Scripts/audit_safety.py

qualify: generate-manifest build-site site-check traceability safety-audit test build

package-local:
	bash Scripts/package_local.sh

verify-package:
	bash Scripts/verify_package.sh
