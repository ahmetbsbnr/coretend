#!/usr/bin/env python3
"""Build and launch the actual local package in an isolated HOME/store fixture."""

import os
import subprocess
import sys
import tempfile
from pathlib import Path


def run(command, *, cwd, env):
    result = subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True, check=False)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode:
        raise SystemExit(result.returncode)


def main():
    repo = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="coretend-packaged-runtime-") as temporary:
        artifact_dir = Path(temporary) / "artifacts"
        environment = os.environ.copy()
        environment["CORETEND_ARTIFACT_DIR"] = str(artifact_dir)
        run(["bash", str(repo / "Scripts/package_local.sh")], cwd=repo, env=environment)
        run(["bash", str(repo / "Scripts/verify_package.sh")], cwd=repo, env=environment)
        app = artifact_dir / "CoreTend.app"
        run([sys.executable, str(repo / "Scripts/test_app_runtime_isolation.py"), str(app)], cwd=repo, env=environment)
    print("Packaged app verified, installed, launched and removed using temporary artifact and HOME/store fixtures.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
