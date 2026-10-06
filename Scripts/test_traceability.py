#!/usr/bin/env python3
import csv
import shutil
import subprocess
import tempfile
from pathlib import Path


def make_fixture(root: Path, evidence: str, extra_field: bool = False, *, priority: str = "M",
                 status: str = "PARTIEL", tests: str = "Tests/fixture.swift",
                 documentation: str = "Documentation/Progress.md", spec_priority: str | None = None,
                 duplicate_row: bool = False, duplicate_capability: bool = False,
                 duplicate_requirement: bool = False) -> Path:
    (root / "Scripts").mkdir(parents=True)
    (root / "Sources/ProductContract").mkdir(parents=True)
    (root / "Tests").mkdir()
    (root / "Documentation/Project").mkdir(parents=True)
    (root / "Scripts/check_traceability.py").write_bytes(
        Path(__file__).with_name("check_traceability.py").read_bytes()
    )
    capabilities = ("shell.menubar", "settings.menubar", "quicklook.extended", "favrec.module", "ui.commandpalette", "clutter.largeold")
    capability_cases = [f' case fixture{i} = "{capability}"' for i, capability in enumerate(capabilities)]
    if duplicate_capability:
        capability_cases.append(' case duplicate = "shell.menubar"')
    (root / "Sources/ProductContract/Capability.swift").write_text("enum Capability {\n" + "\n".join(capability_cases) + "\n}\n")
    (root / "Tests/fixture.swift").write_text("// fixture\n")
    approved = spec_priority or priority
    requirement_rows = f"| FR-01 | {approved} | Fixture |\n"
    if duplicate_requirement:
        requirement_rows += f"| FR-01 | {approved} | Duplicate fixture |\n"
    (root / "Documentation/Project/Cahier-des-charges.md").write_text(
        requirement_rows + "\n## 7. MoSCoW\n| Priorité | Livrables retenus |\n|---|---|\n| **Should** | Menu bar et autres fonctions |\n\nRéconciliation des capacités source : `shell.menubar`, `settings.menubar`, `quicklook.extended`, `favrec.module`, `ui.commandpalette` et `clutter.largeold` sont Should; autres IDs du catalogue §4 sont Must.\n")
    (root / "Documentation/Progress.md").write_text("**Relevé :** 2026-09-27.\n")
    with (root / "Documentation/Traceability.csv").open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["ID", "priority", "description", "code", "tests", "documentation", "evidence", "status", "gap/owner"])
        writer.writerow(["FR-01", priority, "Fixture requirement", "Sources/ProductContract/Capability.swift", tests, documentation, evidence, status, "Engineering"])
        for capability in capabilities:
            cap_priority = "S"
            writer.writerow([capability, cap_priority, "Fixture capability", "Sources/ProductContract/Capability.swift", tests, documentation, evidence, status, "Engineering"])
        if duplicate_row:
            writer.writerow(["FR-01", priority, "Duplicate", "Sources/ProductContract/Capability.swift", tests, documentation, evidence, status, "Engineering"])
    if extra_field:
        csv_path = root / "Documentation/Traceability.csv"
        csv_path.write_text(csv_path.read_text().rstrip("\n") + ",unexpected-column\n")
    return root / "Scripts/check_traceability.py"


def check(evidence: str, extra_field: bool = False, **fixture_options) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory(prefix="coretend-traceability-test-") as temporary:
        script = make_fixture(Path(temporary), evidence, extra_field, **fixture_options)
        return subprocess.run(["python3", str(script)], text=True, capture_output=True)


def main() -> None:
    current = check("Revue du registre 2026-09-27; fixture")
    assert current.returncode == 0, current.stderr

    historical = check("Revue du registre 2026-09-26; unchanged evidence")
    assert historical.returncode == 0, historical.stderr

    for evidence in (
        "Revue du registre 2026-09-28; evidence after the ledger cutoff",
        "Revue du registre 2026-02-30; invalid calendar date",
        "Fixture without anchored review date 2026-09-27",
    ):
        stale = check(evidence)
        assert stale.returncode != 0, f"outdated or malformed evidence was accepted: {evidence}"

    malformed = check("Revue du registre 2026-09-27; fixture", extra_field=True)
    assert malformed.returncode != 0, "CSV rows with extra columns must be rejected"

    duplicate = check("Revue du registre 2026-09-27; fixture", duplicate_row=True)
    assert duplicate.returncode != 0, "duplicate traceability IDs must be rejected"

    duplicate_source = check("Revue du registre 2026-09-27; fixture", duplicate_capability=True)
    assert duplicate_source.returncode != 0 and "duplicate capability IDs" in duplicate_source.stderr, duplicate_source.stderr

    duplicate_requirement = check("Revue du registre 2026-09-27; fixture", duplicate_requirement=True)
    assert duplicate_requirement.returncode != 0 and "duplicate requirement ID" in duplicate_requirement.stderr, duplicate_requirement.stderr

    demoted_must = check("Revue du registre 2026-09-27; fixture", priority="S", spec_priority="M")
    assert demoted_must.returncode != 0, "a Must demoted in the traceability CSV must be rejected"

    capability_demotion = check("Revue du registre 2026-09-27; fixture", priority="M")
    assert capability_demotion.returncode == 0, capability_demotion.stderr

    incomplete_should = check(
        "2026-09-27: partial fixture",
        priority="S",
        tests="",
    )
    assert incomplete_should.returncode != 0, "an active Should row without test traceability must be rejected"

    print("Traceability fixtures passed: historical/current dates accepted; future, invalid, unanchored and malformed-column rows rejected.")


if __name__ == "__main__":
    main()
