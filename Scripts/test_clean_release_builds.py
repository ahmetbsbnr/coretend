#!/usr/bin/env python3
import hashlib
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


PRODUCTS = ("CoreTendApp", "CoreTendCLI")


def reset_scratch_directory(scratch: Path, owned_root: Path) -> None:
    if owned_root.is_symlink() or scratch.is_symlink():
        raise RuntimeError("Refusing symlinked reproducibility scratch path")
    root = owned_root.resolve(strict=True)
    resolved = scratch.resolve(strict=True)
    if resolved == root or root not in resolved.parents or not resolved.is_dir():
        raise RuntimeError(f"Refusing scratch reset outside owned root: {scratch}")
    shutil.rmtree(resolved)
    resolved.mkdir()


def main() -> None:
    package_root = Path(__file__).resolve().parents[1]
    observed: dict[tuple[str, str], str] = {}
    build_cache = package_root / ".build"
    if build_cache.is_symlink():
        raise RuntimeError("Refusing symlinked SwiftPM .build cache")
    build_cache.mkdir(exist_ok=True)
    if not build_cache.is_dir():
        raise RuntimeError("SwiftPM .build cache is not a directory")
    with tempfile.TemporaryDirectory(prefix="coretend-clean-release-", dir=build_cache) as temporary:
        owned_root = Path(temporary)
        for product in PRODUCTS:
            scratch = owned_root / product
            scratch.mkdir()
            for build_number, build_name in enumerate(("first", "second")):
                if build_number:
                    reset_scratch_directory(scratch, owned_root)
                command = [
                    "swift", "build", "-c", "release",
                    "--scratch-path", str(scratch),
                    "--product", product,
                ]
                environment = os.environ.copy()
                # SwiftPM defaults to the host's current OS deployment target.
                # Pin this smoke to the project's minimum so runner/local SDK
                # differences don't silently change the product binary.
                environment["MACOSX_DEPLOYMENT_TARGET"] = "14.0"
                result = subprocess.run(
                    command, cwd=package_root, text=True,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    timeout=600, check=False, env=environment,
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
    print("Two cold builds used same physical scratch path per product, cleared between builds; Package.swift release linker policy uses ld -reproducible; all outputs removed with the unique temporary root.")


if __name__ == "__main__":
    main()
