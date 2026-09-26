.PHONY: test build generate-manifest build-site site-check traceability safety-audit install-smoke qualify package-local verify-package verify-install-package

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

install-smoke:
	bash Scripts/test_install_local.sh

qualify: generate-manifest build-site site-check traceability safety-audit install-smoke test build

package-local:
	bash Scripts/package_local.sh

verify-package:
	bash Scripts/verify_package.sh

verify-install-package: package-local
	bash Scripts/test_install_local.sh Artifacts/CoreTend.app
