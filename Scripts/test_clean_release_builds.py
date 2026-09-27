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
                    "-Xlinker", "-no_uuid",
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
                if os.environ.get("CI") == "true":
                    shutil.copy2(executable, package_root / ".build" / f"{product}-{build_name}-repro-diagnostic")

    for product in PRODUCTS:
        if observed[("first", product)] != observed[("second", product)]:
            first = package_root / ".build" / f"{product}-first-repro-diagnostic"
            second = package_root / ".build" / f"{product}-second-repro-diagnostic"
            if first.is_file() and second.is_file():
                comparison = subprocess.run(["cmp", "-l", str(first), str(second)], text=True, stdout=subprocess.PIPE, check=False)
                print(f"First differing byte positions for {product}:\n" + "\n".join(comparison.stdout.splitlines()[:32]))
                for binary in (first, second):
                    result = subprocess.run(["otool", "-l", str(binary)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
                    print(f"Load-command SHA {binary.name}: {hashlib.sha256(result.stdout.encode()).hexdigest()}")
                    print("\n".join(line for line in result.stdout.splitlines() if any(key in line for key in (
                        "Load command ", "cmd LC_", "sectname", "segname", "size ", "offset ",
                        "fileoff ", "filesize ", "dataoff ", "datasize ", "symoff ", "nsyms ", "stroff ", "strsize ",
                    ))))
                    symoff_match = next((line for line in result.stdout.splitlines() if line.strip().startswith("symoff ")), None)
                    if symoff_match:
                        symoff = int(symoff_match.split()[-1])
                        offsets = [int(line.split()[0]) - 1 for line in comparison.stdout.splitlines()[:32]]
                        symbol_index = max(0, (offsets[0] - symoff) // 16)
                        symbols = subprocess.run(["nm", "-pa", str(binary)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
                        print(f"nm -pa near nlist index {symbol_index} ({binary.name}):")
                        print("\n".join(symbols.stdout.splitlines()[symbol_index:symbol_index + 8]))
            raise RuntimeError(f"{product} is not reproducible across clean scratch builds")
        print(f"{product}: byte-identical across clean scratch builds")
    print("Two cold builds used the same physical scratch path per product, cleared between builds; LC_UUID disabled for deterministic Mach-O output; all outputs removed with the unique temporary root.")


if __name__ == "__main__":
    main()
