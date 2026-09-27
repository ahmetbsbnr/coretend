#!/usr/bin/env python3
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time


def main():
    executable = Path(sys.argv[1]).resolve()
    root = Path(tempfile.mkdtemp(prefix="coretend-cli-interrupt-"))
    process = None
    try:
        for index in range(30_000):
            (root / f"fixture-{index:05d}.dat").touch()

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
