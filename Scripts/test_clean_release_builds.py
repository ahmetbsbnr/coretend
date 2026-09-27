#!/usr/bin/env python3
import hashlib
import subprocess
import tempfile
from contextlib import contextmanager
from pathlib import Path
from collections.abc import Iterator


PRODUCTS = ("CoreTendApp", "CoreTendCLI")


@contextmanager
def temporary_scratch_link(stable_path: Path, scratch: Path) -> Iterator[None]:
    stable_path.symlink_to(scratch, target_is_directory=True)
    try:
        yield
    finally:
        try:
            if stable_path.is_symlink() and stable_path.resolve(strict=True) == scratch.resolve(strict=True):
                stable_path.unlink()
        except FileNotFoundError:
            pass


def main() -> None:
    package_root = Path(__file__).resolve().parents[1]
    observed: dict[tuple[str, str], str] = {}
    build_cache = package_root / ".build"
    if build_cache.is_symlink():
        raise RuntimeError("Refusing symlinked SwiftPM .build cache")
    build_cache.mkdir(exist_ok=True)
    if not build_cache.is_dir():
        raise RuntimeError("SwiftPM .build cache is not a directory")
    stable_scratch_path = build_cache / "qualify-clean-release-scratch"
    if stable_scratch_path.exists() or stable_scratch_path.is_symlink():
        raise RuntimeError(f"Refusing existing reproducibility scratch path: {stable_scratch_path}")

    for build_name in ("first", "second"):
        with tempfile.TemporaryDirectory(prefix="coretend-clean-release-") as temporary:
            scratch = Path(temporary) / "scratch"
            scratch.mkdir()
            with temporary_scratch_link(stable_scratch_path, scratch):
                for product in PRODUCTS:
                    command = [
                        "swift", "build", "-c", "release",
                        "--scratch-path", str(stable_scratch_path),
                        "--product", product,
                    ]
                    result = subprocess.run(
                        command, cwd=package_root, text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                        timeout=600, check=False,
                    )
                    if result.returncode != 0:
                        raise RuntimeError(f"{build_name} {product} build failed:\n{result.stdout}")
                    if "warning:" in result.stdout.lower():
                        raise RuntimeError(f"{build_name} {product} emitted a build warning:\n{result.stdout}")

                    executable = scratch / "release" / product
                    if not executable.is_file():
                        raise RuntimeError(f"{build_name} did not produce {executable}")
                    digest = hashlib.sha256(executable.read_bytes()).hexdigest()
                    observed[(build_name, product)] = digest
                    print(f"{build_name} {product}: {digest}")

    for product in PRODUCTS:
        if observed[("first", product)] != observed[("second", product)]:
            raise RuntimeError(f"{product} is not reproducible across clean scratch builds")
        print(f"{product}: byte-identical across clean scratch builds")
    print("Two cold builds used separate temporary roots and scratch directories through one stable workspace path; all scratch outputs and the symlink were removed.")


if __name__ == "__main__":
    main()
