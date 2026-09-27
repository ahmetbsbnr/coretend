#!/usr/bin/env python3
import csv
import shutil
import subprocess
import tempfile
from pathlib import Path


def make_fixture(root: Path, evidence: str, extra_field: bool = False) -> Path:
    (root / "Scripts").mkdir(parents=True)
    (root / "Sources/ProductContract").mkdir(parents=True)
    (root / "Tests").mkdir()
    (root / "Documentation/Project").mkdir(parents=True)
    (root / "Scripts/check_traceability.py").write_bytes(
        Path(__file__).with_name("check_traceability.py").read_bytes()
    )
    (root / "Sources/ProductContract/Capability.swift").write_text("// no capabilities\n")
    (root / "Tests/fixture.swift").write_text("// fixture\n")
    (root / "Documentation/Project/Cahier-des-charges.md").write_text("| FR-01 | M | Fixture |\n")
    (root / "Documentation/Progress.md").write_text("**Relevé :** 2026-09-27.\n")
    with (root / "Documentation/Traceability.csv").open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["ID", "priority", "description", "code", "tests", "documentation", "evidence", "status", "gap/owner"])
        writer.writerow(["FR-01", "M", "Fixture requirement", "Sources/ProductContract/Capability.swift", "Tests/fixture.swift", "Documentation/Progress.md", evidence, "PARTIEL", "Engineering"])
    if extra_field:
        csv_path = root / "Documentation/Traceability.csv"
        csv_path.write_text(csv_path.read_text().rstrip("\n") + ",unexpected-column\n")
    return root / "Scripts/check_traceability.py"


def check(evidence: str, extra_field: bool = False) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="coretend-traceability-test-") as temporary:
        script = make_fixture(Path(temporary), evidence, extra_field)
        return subprocess.run(["python3", str(script)], text=True, capture_output=True)


def main() -> None:
    current = check("Revue du registre 2026-09-27; fixture")
    assert current.returncode == 0, current.stderr

    for evidence in (
        "Revue du registre 2026-09-26; stale fixture",
        "Revue du registre 2026-02-30; invalid calendar date",
        "Fixture without anchored review date 2026-09-27",
    ):
        stale = check(evidence)
        assert stale.returncode != 0, f"outdated or malformed evidence was accepted: {evidence}"

    malformed = check("Revue du registre 2026-09-27; fixture", extra_field=True)
    assert malformed.returncode != 0, "CSV rows with extra columns must be rejected"

    print("Traceability fixtures passed: current ISO date accepted; stale, invalid, unanchored and malformed-column rows rejected.")


if __name__ == "__main__":
    main()
