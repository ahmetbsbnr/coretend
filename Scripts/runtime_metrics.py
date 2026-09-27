"""Read CPU and resident-memory samples for one explicitly supplied process."""

import math
import os
import subprocess


def parse_process_metrics(output):
    fields = output.split()
    if len(fields) != 2:
        raise ValueError("ps must return CPU percent and RSS KiB")
    try:
        cpu_percent = float(fields[0])
        rss_kib = int(fields[1])
    except ValueError as error:
        raise ValueError("ps returned nonnumeric process metrics") from error
    try:
        rss_mib = rss_kib / 1024
    except OverflowError as error:
        raise ValueError("ps returned invalid process memory") from error
    if not math.isfinite(cpu_percent) or cpu_percent < 0 or rss_kib < 0 or not math.isfinite(rss_mib):
        raise ValueError("ps returned invalid process metrics")
    return cpu_percent, rss_mib


def process_metrics(process_id):
    if not isinstance(process_id, int) or process_id <= 0:
        raise ValueError("process_id must be a positive process ID")
    result = subprocess.run(
        ["ps", "-o", "%cpu=", "-o", "rss=", "-p", str(process_id)],
        capture_output=True,
        text=True,
        check=False,
        # A decimal-comma locale makes ps print "68,8"; the parser accepts only C-locale output.
        env={**os.environ, "LC_ALL": "C", "LANG": "C"},
    )
    if result.returncode != 0:
        raise RuntimeError(f"ps could not inspect process {process_id}: {result.stderr.strip()}")
    return parse_process_metrics(result.stdout)
