#!/usr/bin/env python3
"""Measure window detection and sampled RSS for the packaged app in isolated fixtures.

Run after make package-local. No keystrokes or destructive actions are performed.
Window existence is not rendered-content readiness; ps CPU is a lifetime average.
"""
import json
import shutil
import statistics
import subprocess
import tempfile
import time
from pathlib import Path

from runtime_metrics import process_metrics

ROOT = Path(__file__).resolve().parents[1]
RUN_COUNT = 5


def main():
    results = []
    with tempfile.TemporaryDirectory(prefix="coretend-perf-window-") as temporary:
        root = Path(temporary).resolve()
        helper = root / "window-helper"
        subprocess.run(["swiftc", "-O", str(ROOT / "Scripts/capture_window_helper.swift"),
                        "-o", str(helper)], check=True)
        app = root / "CoreTend.app"
        shutil.copytree(ROOT / "Artifacts/CoreTend.app", app)
        for index in range(RUN_COUNT):
            fixture = root / f"run-{index}"
            fixture.mkdir()
            for name in ("home", "store", "tmp"):
                (fixture / name).mkdir()
            environment = {
                "PATH": "/usr/bin:/bin", "HOME": str(fixture / "home"),
                "CFFIXED_USER_HOME": str(fixture / "home"),
                "TMPDIR": str(fixture / "tmp") + "/", "CORETEND_TEST_MODE": "1",
                "CORETEND_TEST_STORE_DIR": str(fixture / "store"),
                "CORETEND_TEST_ONBOARDING_COMPLETED": "1", "CORETEND_TEST_LANGUAGE": "fr",
                "CORETEND_TEST_APPEARANCE": "dark", "CORETEND_TEST_LAST_DESTINATION": "overview",
            }
            started = time.monotonic()
            process = subprocess.Popen([str(app / "Contents/MacOS/CoreTendApp")],
                                       env=environment, stdout=subprocess.DEVNULL,
                                       stderr=subprocess.DEVNULL)
            try:
                while True:
                    if process.poll() is not None:
                        raise RuntimeError("App exited before window detection")
                    found = subprocess.run([str(helper), "window", str(process.pid)],
                                           capture_output=True, text=True, timeout=5)
                    if found.returncode == 0:
                        break
                    if time.monotonic() - started >= 15:
                        raise TimeoutError("No normal window detected in 15 seconds")
                    time.sleep(0.05)
                ready = time.monotonic() - started
                samples = []
                for _ in range(10):
                    time.sleep(0.5)
                    cpu, rss = process_metrics(process.pid)
                    samples.append({"ps_lifetime_cpu_percent": cpu, "rss_mib": rss})
                results.append({"window_detected_s": ready, "samples": samples})
                print(f"run={index + 1} window_s={ready:.3f} "
                      f"sampled_rss_max_mib={max(s['rss_mib'] for s in samples):.3f}", flush=True)
            finally:
                if process.poll() is None:
                    process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    report = {
        "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "method": "CGWindow layer0 >200x200 polling with helper overhead; window existence only; ps lifetime CPU",
        "samples": results,
    }
    output = ROOT / "Artifacts/Performance/P4-43-app.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"window_median_s={statistics.median(r['window_detected_s'] for r in results):.3f}")


if __name__ == "__main__":
    main()
