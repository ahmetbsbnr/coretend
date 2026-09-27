.PHONY: test build generate-manifest build-site site-check traceability safety-audit architecture-audit install-smoke uninstall-smoke app-runtime-smoke test-cli-interrupt qualify package-local verify-package verify-install-package benchmark-scan

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

architecture-audit:
	python3 Scripts/test_architecture.py
	python3 Scripts/check_architecture.py

install-smoke:
	bash Scripts/test_install_local.sh

uninstall-smoke:
	python3 Scripts/test_uninstall_local.py

app-runtime-smoke:
	swift build -c release --product CoreTendApp
	python3 Scripts/test_app_runtime_isolation.py .build/release/CoreTendApp

qualify: generate-manifest build-site site-check traceability safety-audit architecture-audit install-smoke uninstall-smoke app-runtime-smoke test test-cli-interrupt

test-cli-interrupt: build
	python3 Scripts/test_cli_interrupt.py .build/debug/CoreTendCLI

package-local:
	bash Scripts/package_local.sh

verify-package:
	bash Scripts/verify_package.sh

verify-install-package: package-local
	bash Scripts/test_install_local.sh Artifacts/CoreTend.app

benchmark-scan:
	swift build -c release --product CoreTendCLI
	python3 Scripts/benchmark_scan.py
