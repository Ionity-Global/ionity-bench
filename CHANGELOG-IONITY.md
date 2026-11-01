# Ionity Bench — Changelog

Upstream engine changes are tracked in [`ChangeLog`](ChangeLog) (Phoronix Test Suite). This file tracks the Ionity layer only.

## 1.0.0 "Centurion" — 2026-11-01

Initial public release, forked from Phoronix Test Suite 10.8.6 (`1bc6fc9c8`, "pts-core: Some fixes, mostly on Apple").

### Engine (GPL-3.0-or-later)
- `IONITY_BENCH_*` defines in `pts-core/pts-core.php`; `pts_core::program_title()` now reports *Ionity Bench vX (Phoronix Test Suite vY)*, with `engine_title()` and `ionity_banner()` added.
- New on-disk repository namespace `ionity/` resolved like `local/` (`pts_openbenchmarking::local_repositories()` / `is_local_repository()`), wired through index refresh, identifier resolution, local test/suite enumeration, directory creation, changelog lookups, `info`, the web embed and the `dump_*` / `openbenchmarking_*` commands.
- New `ionity` command (`ionity_bench`, `ionity_info`, `ib`) listing the bundled Ionity suites and profiles.
- Result files gain `<Generated><IonityBench>` next to `<TestClient>`.
- Result viewer, HTML template, HTML/PDF export and footers restyled in the Ionity palette with the Ionity Global logo; `short-description.txt`, `ionity-bench.desktop` and `install-sh` updated.
- `ionity-bench` and `ionity-bench.bat` launchers with suite / profile short names.

### Ionity test profiles (`ob-cache/test-profiles/ionity/`)
`io-core`, `io-mem`, `io-thermal-sustain`, `io-latency-rt`, `io-ai-matmul`, `io-telemetry-sqlite`, `io-json-mqtt`, `io-crypto-edge`, `io-storage-edge`, `io-net-loopback` — all self-contained (C or Python 3 embedded in `install.sh`), offline, with per-option result scales where needed.

### Ionity suites (`ob-cache/test-suites/ionity/`)
`quick-check`, `edge-node`, `iot-gateway`, `power-thermal`, `ai-edge`, `storage`, `timeseries-db`, `server-rms`, `workstation-design`, `full-spectrum`. Upstream tests pinned to bundled versions with explicit argument strings.

### Documentation & CI
- `README.md` (Ionity), `NOTICE-IONITY.md`, `documentation/ionity-bench.md`; upstream README preserved as `documentation/README-upstream-phoronix-test-suite.md`.
- GitHub Actions: PHP lint, XML and shell validation, and a real `ionity/quick-check` run on every push.

---
*(c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd — All Rights Reserved — TM2 · Policy 986 AED*
