"""Observe Internet sockets owned by one explicitly supplied process."""

import shutil
import subprocess


def internet_socket_processes(process_id):
    lsof = shutil.which("lsof")
    if lsof is None:
        raise RuntimeError("lsof is required for runtime network observation")
    if not isinstance(process_id, int) or process_id <= 0:
        raise ValueError("process_id must be a positive process ID")

    result = subprocess.run(
        [lsof, "-nP", "-a", "-p", str(process_id), "-i", "-t"],
        capture_output=True,
        text=True,
        check=False,
    )
    output = result.stdout.split()
    if result.returncode not in (0, 1) or (result.returncode == 1 and (output or result.stderr.strip())):
        raise RuntimeError(f"lsof could not inspect process {process_id}: {result.stderr.strip()}")
    try:
        process_ids = {int(line) for line in output}
    except ValueError as error:
        raise RuntimeError("lsof returned an invalid process ID") from error
    if result.returncode == 0 and not process_ids:
        raise RuntimeError("lsof reported matches without returning a process ID")
    return process_ids
