#!/usr/bin/env python3
"""Measure release CLI metadata scan on an isolated synthetic tree."""
import os
import pathlib
import platform
import statistics
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLI = ROOT / ".build" / "release" / "CoreTendCLI"
FILE_COUNT = 10_000
DIRECTORY_COUNT = 100
RUN_COUNT = 5
PAYLOADS = (b"", b"a" * 4_096, b"b" * 4_096, b"c" * 65_536)
TIMEOUT_SECONDS = 120


def create_fixture(root: pathlib.Path) -> int:
    total_bytes = 0
    for index in range(FILE_COUNT):
        directory = root / f"dir-{index // (FILE_COUNT // DIRECTORY_COUNT):03d}"
        directory.mkdir(exist_ok=True)
        payload = PAYLOADS[index % len(PAYLOADS)]
        (directory / f"file-{index:05d}.dat").write_bytes(payload)
        total_bytes += len(payload)
    return total_bytes


def run_scan(root: pathlib.Path, run_number: int) -> tuple[float, float, float]:
    started = time.perf_counter()
    output_path = root.parent / f"scan-output-{run_number}.txt"
    with output_path.open("w") as output:
        process = subprocess.Popen(
            [str(CLI), "scan", "--root", str(root), "--rule", "scan.explore"],
            stdout=output,
            stderr=subprocess.PIPE,
        )
        deadline = started + TIMEOUT_SECONDS
        while True:
            waited_pid, status, usage = os.wait4(process.pid, os.WNOHANG)
            if waited_pid == process.pid:
                process.returncode = os.waitstatus_to_exitcode(status)
                break
            if time.monotonic() >= deadline:
                process.terminate()
                os.wait4(process.pid, 0)
                raise TimeoutError(f"scan exceeded {TIMEOUT_SECONDS} seconds")
            time.sleep(0.02)

    elapsed = time.perf_counter() - started
    error = process.stderr.read().decode(errors="replace")
    if process.returncode != 0:
        raise RuntimeError(f"scan exited {process.returncode}: {error}")
    summary = output_path.read_text().splitlines()[-1]
    if summary != f"{FILE_COUNT} files":
        raise RuntimeError(f"expected {FILE_COUNT} results, got {summary!r}")
    output_path.unlink()
    rss_bytes = usage.ru_maxrss if platform.system() == "Darwin" else usage.ru_maxrss * 1_024
    cpu_seconds = usage.ru_utime + usage.ru_stime
    return elapsed, cpu_seconds, rss_bytes / (1_024 * 1_024)


def main() -> None:
    if not CLI.is_file():
        raise SystemExit("Release CLI missing; run 'swift build -c release --product CoreTendCLI'.")

    with tempfile.TemporaryDirectory(prefix="coretend-perf-") as temporary_root:
        root = pathlib.Path(temporary_root) / "scan-tree"
        root.mkdir()
        total_bytes = create_fixture(root)
        results = [run_scan(root, index) for index in range(1, RUN_COUNT + 1)]

    print(f"host={platform.machine()} os={platform.mac_ver()[0] or platform.system()}")
    print(f"files={FILE_COUNT} directories={DIRECTORY_COUNT} logical_bytes={total_bytes} runs={RUN_COUNT}")
    for index, (wall, cpu, rss) in enumerate(results, start=1):
        print(f"run={index} wall_s={wall:.3f} cpu_s={cpu:.3f} peak_rss_mib={rss:.1f}")
    print("median_warm_runs_2_to_5:", end=" ")
    for column, label in enumerate(("wall_s", "cpu_s", "peak_rss_mib")):
        print(f"{label}={statistics.median(sample[column] for sample in results[1:]):.3f}", end=" ")
    print()


if __name__ == "__main__":
    main()
