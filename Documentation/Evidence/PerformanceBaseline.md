# Performance baseline

## Synthetic release CLI scan — 2026-09-27

- Host: arm64, macOS 27.0, Apple Swift 6.4.
- Reproduce with `make benchmark-scan`. Build time and fixture creation are excluded from timings.
- Workload: 10,000 regular files in 100 directories; deterministic size pattern repeats 0, 4 KiB, 4 KiB, 64 KiB (184,320,000 logical bytes total). Fixture lives in a unique temporary directory and is removed after the run.
- Command per sample: `.build/release/CoreTendCLI scan --root <temporary-fixture> --rule scan.explore`. CLI formats all results to a temporary output file; script checks final result count and requires exit status 0. Five fresh processes run against same fixture; sample 1 is reported separately, samples 2–5 form warm median.
- Warm median: **0.913 s wall**, **0.979 s child CPU**, **74.18 MiB peak RSS**. Individual samples: 0.904/0.983/74.2, 0.926/0.980/74.2, 0.902/0.979/74.2, 0.925/0.976/74.2, 0.901/0.980/74.2 (wall/CPU/RSS).
- No budget is inferred from one host and synthetic workload. This measures release CLI startup + metadata traversal + text formatting, not app window readiness, native UI responsiveness, image hashing, or a representative user library. OS caches and host load were not controlled. Repeat on realistic fixtures and additional supported hosts before setting budgets.

## Packaged app fixture startup and residency sample — 2026-09-27

- Host: arm64, macOS 27.0, Apple Swift 6.4. Reproduce with `make app-runtime-smoke` or full `make qualify`; app is the actual unsigned Release package installed under fixture `HOME`, with fixture store and menu-bar mode enabled.
- Two fixture launches each reached first SQLite observation in **1.094 s**. This is store readiness, not main-window readiness.
- Each run collected 13 socket/isolation samples approximately 0.5 s apart after store creation. Run A: `ps` `%CPU` median **0.0**, maximum **55.2**; resident memory median **92.5 MiB**, maximum **95.4 MiB**. Run B: `%CPU` median **0.0**, maximum **69.1**; RSS median **96.3 MiB**, maximum **97.6 MiB**. `%CPU` is `ps` lifetime average at each observation, including startup, not instantaneous idle utilization. RSS is sampled, not peak resident memory.
- These measurements describe two synthetic launches on one host. They do not set budgets or claim UI responsiveness; user load and host load were not controlled.

## Remaining NFR-09 evidence

Native app startup-to-window, UI interaction latency, CPU/RSS during real scans, animation at rest, a representative corpus and additional hosts remain unmeasured. NFR-09 stays `PARTIEL`.
