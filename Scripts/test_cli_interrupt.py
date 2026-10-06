#!/usr/bin/env python3
import json
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time


def verify_usage_contract(executable, root):
    def invoke(arguments):
        return subprocess.run(
            [str(executable), *arguments],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=10,
        )

    help_result = invoke(["help"])
    if help_result.returncode != 0 or "Usage:" not in help_result.stdout:
        raise RuntimeError(f"help contract failed: {help_result.returncode}, {help_result.stderr!r}")

    french_help = invoke(["--lang", "fr", "help"])
    if french_help.returncode != 0 or "Utilisation :" not in french_help.stdout:
        raise RuntimeError(f"French help contract failed: {french_help.returncode}, {french_help.stdout!r}, {french_help.stderr!r}")

    english_version = invoke(["version"])
    french_version = invoke(["--lang", "fr", "version"])
    if english_version.returncode != 0 or english_version.stdout != "CoreTend 2.1.2\n":
        raise RuntimeError(f"English version contract failed: {english_version.returncode}, {english_version.stdout!r}")
    if french_version.returncode != 0 or french_version.stdout != "CoreTend 2.1.2\n":
        raise RuntimeError(f"French version contract failed: {french_version.returncode}, {french_version.stdout!r}")

    bad_language = invoke(["--lang", "de", "help"])
    if bad_language.returncode != 2 or bad_language.stderr != "Invalid or unsupported command. Run 'coretend help'.\n":
        raise RuntimeError(f"invalid language contract failed: {bad_language.returncode}, {bad_language.stderr!r}")

    unsupported = invoke(["delete", "--permanently"])
    if unsupported.returncode != 2 or unsupported.stderr != "Invalid or unsupported command. Run 'coretend help'.\n":
        raise RuntimeError(f"unsupported command contract failed: {unsupported.returncode}, {unsupported.stderr!r}")

    missing_store = invoke(["record", "list"])
    if missing_store.returncode != 2 or missing_store.stderr != "Provide --store PATH. The CLI never guesses a user store location.\n":
        raise RuntimeError(f"missing store contract failed: {missing_store.returncode}, {missing_store.stderr!r}")

    missing_store_fr = invoke(["--lang", "fr", "record", "list"])
    if missing_store_fr.returncode != 2 or "Fournissez --store CHEMIN" not in missing_store_fr.stderr:
        raise RuntimeError(f"French missing store contract failed: {missing_store_fr.returncode}, {missing_store_fr.stderr!r}")

    malformed_value = invoke(["record", "list", "--store", "--store"])
    if malformed_value.returncode != 2 or malformed_value.stderr != unsupported.stderr:
        raise RuntimeError(f"malformed option contract failed: {malformed_value.returncode}, {malformed_value.stderr!r}")

    unsupported_fr = invoke(["--lang", "fr", "delete", "--permanently"])
    if unsupported_fr.returncode != 2 or "Commande invalide ou non prise en charge" not in unsupported_fr.stderr:
        raise RuntimeError(f"French unsupported command contract failed: {unsupported_fr.returncode}, {unsupported_fr.stderr!r}")

    absent_store_path = root / "absent.sqlite"
    store_failure = invoke(["record", "list", "--store", str(absent_store_path)])
    if store_failure.returncode != 1 or store_failure.stdout != "Unable to read the requested store.\n" or absent_store_path.exists():
        raise RuntimeError(f"explicit store failure contract failed: {store_failure.returncode}, {store_failure.stdout!r}")

    absent_store_fr_path = root / "absent-fr.sqlite"
    store_failure_fr = invoke(["--lang", "fr", "record", "list", "--store", str(absent_store_fr_path)])
    if store_failure_fr.returncode != 1 or store_failure_fr.stdout != "Impossible de lire le store demandé.\n" or absent_store_fr_path.exists():
        raise RuntimeError(f"French explicit store failure contract failed: {store_failure_fr.returncode}, {store_failure_fr.stdout!r}")

    absent_root = root / "absent-scan-root"
    partial_scan = invoke(["scan", "--root", str(absent_root), "--rule", "scan.explore", "--format", "json"])
    report = json.loads(partial_scan.stdout)
    if partial_scan.returncode != 2 or absent_root.exists() or report.get("complete") is not False:
        raise RuntimeError(f"partial scan contract failed: {partial_scan.returncode}, {partial_scan.stdout!r}")

    partial_scan_fr = invoke(["--lang", "fr", "scan", "--root", str(absent_root), "--rule", "scan.explore"])
    if partial_scan_fr.returncode != 2 or "0 fichiers" not in partial_scan_fr.stdout or "Problème d’analyse [missing]" not in partial_scan_fr.stdout:
        raise RuntimeError(f"French partial scan contract failed: {partial_scan_fr.returncode}, {partial_scan_fr.stdout!r}")

    print("CLI usage integration passed: EN/FR help/errors and documented exit codes.")


def main():
    executable = Path(sys.argv[1]).resolve()
    root = Path(tempfile.mkdtemp(prefix="coretend-cli-interrupt-"))
    process = None
    try:
        for index in range(50_000):
            (root / f"fixture-{index:05d}.dat").touch()

        verify_usage_contract(executable, root)

        process = subprocess.Popen(
            [str(executable), "scan", "--root", str(root), "--rule", "scan.explore"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        time.sleep(0.6)
        if process.poll() is not None:
            raise RuntimeError("fixture scan ended before interrupt could be sent")
        process.send_signal(signal.SIGINT)
        _, stderr = process.communicate(timeout=15)
        if process.returncode != 130:
            raise RuntimeError(f"SIGINT must exit cleanly with 130, got {process.returncode}; stderr={stderr!r}")
        print("CLI SIGINT integration passed: interrupted fixture scan exits 130.")
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()
        shutil.rmtree(root)


if __name__ == "__main__":
    main()
