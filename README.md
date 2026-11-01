<!--
========================================================================================
AEDI - IONITY GLOBAL - IONITY BENCH
Author: Johan Wilhelm van Antwerp | Ionity (Pty) Ltd | AEDI
Document ID: DOC-2026-11-001 | Version: 1.0.0 | Updated: 2026-11-01 SAST
Governance: Policy 986 AED | Code: GPL-3.0-or-later | Brand: All Rights Reserved - TM2
(c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - All Rights Reserved - TM2
Web: https://www.ionity.today | https://www.ionity.world | Ref: https://www.ionity.co.za
Classification: PUBLIC | Building Tomorrow, Today. | Anything is Possible with God.
========================================================================================
-->

<p align="center">
  <img src="pts-core/static/images/ionity-global-logo.png" alt="Ionity Global" width="420" />
</p>

<h1 align="center">Ionity Bench</h1>

<p align="center"><strong>The Ionity Global benchmarking platform for edge, IoT, AI and server hardware.</strong><br/>
Built on the <a href="https://www.phoronix-test-suite.com/">Phoronix Test Suite</a> engine &middot; v1.0.0 &ldquo;Centurion&rdquo; &middot; <em>Building Tomorrow, Today.</em></p>

<p align="center">
  <a href="COPYING"><img alt="License: GPL-3.0-or-later" src="https://img.shields.io/badge/code-GPL--3.0--or--later-blue.svg"></a>
  <img alt="Engine" src="https://img.shields.io/badge/engine-Phoronix%20Test%20Suite%2010.8.6-0d1b2a.svg">
  <img alt="Ionity Bench" src="https://img.shields.io/badge/Ionity%20Bench-1.0.0%20Centurion-00BFFF.svg">
  <img alt="Governance" src="https://img.shields.io/badge/governance-Policy%20986%20AED-0d1b2a.svg">
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Linux%20%7C%20BSD%20%7C%20macOS%20%7C%20Windows-00c6ff.svg">
</p>

---

## What is Ionity Bench?

Ionity Bench is a fork of the Phoronix Test Suite that Ionity (Pty) Ltd uses to qualify the hardware it designs, deploys and manages: Raspberry Pi and Radxa class edge nodes, fanless IoT gateways, Hailo-accelerated AI boxes, SATA/NVMe storage carriers, the TimescaleDB/PostgreSQL back-ends behind our Remote Management Systems (RMS) and SCADA integrations, and the engineering workstations that run KiCad and CAD/CAM.

It keeps 100% of the upstream engine - every one of the 600+ OpenBenchmarking.org test profiles still works - and adds:

* **Ten Ionity-authored test profiles** (`ionity/io-*`) written in C and Python 3 with **no downloads and no network dependency**. They install and run on air-gapped devices with nothing more than a C compiler and Python 3.
* **Ten curated Ionity suites** (`ionity/*`) that pin the upstream tests to the exact configurations we care about, so a suite finishes in a predictable time instead of fanning out over thousands of option combinations.
* **A branded `ionity-bench` launcher**, an `ionity` overview command, a result viewer and PDF/HTML export styled in the Ionity palette, and an `ionity` on-disk repository namespace alongside `local/`, `pts/`, `system/` and `git/`.

```console
$ ./ionity-bench quick-check          # ~5 minute smoke test
$ ./ionity-bench edge-node            # SBC / gateway qualification profile
$ ./ionity-bench                      # banner + everything that ships in this release
```

## Ionity test profiles

| Identifier | Measures | Scale | Why it is in the box |
|---|---|---|---|
| `ionity/io-core` | Mixed integer / FP / branch CPU kernel (PRNG + FNV-1a, Mandelbrot, prime sieve) on 1, 4 or all cores | ION Points | Comparable compute score from an ESP32-class Linux SoC to a server |
| `ionity/io-mem` | STREAM-style Copy / Scale / Add / Triad, arrays auto-sized to the cache and RAM of the device | MB/s | Memory bandwidth is what limits most SBC workloads |
| `ionity/io-thermal-sustain` | All-core FMA load for 1 / 3 / 10 minutes, throughput sampled every second | Sustained Efficiency % | Detects throttling in sealed enclosures; logs SoC temperature on Linux |
| `ionity/io-latency-rt` | 1 ms timer wake-up jitter (max, p99, average) | Microseconds (lower is better) | Soft real-time control loops, SCADA polling, RMS heartbeats |
| `ionity/io-ai-matmul` | Blocked 512x512 GEMM in FP32 and INT8 | GFLOPS / GOPS | CPU inference proxy for devices without, or alongside, an NPU |
| `ionity/io-telemetry-sqlite` | 256-device IoT telemetry into SQLite (WAL, batched): ingest, window queries, mixed | Rows/s, Queries/s, Ops/s | Edge gateway and RMS node local buffering |
| `ionity/io-json-mqtt` | MQTT-style JSON encode + decode + validate: single reading, 100-reading batch, Sparkplug-B | Messages/s | Brokers, bridges and collectors live on JSON |
| `ionity/io-crypto-edge` | SHA-256 / SHA-512 / BLAKE2b blocks, HMAC-SHA256 small messages, PBKDF2 | MB/s, Messages/s, Derivations/s | TLS, OTA verification, signed telemetry, credential derivation |
| `ionity/io-storage-edge` | Durable 4K random write + fsync, 4K random read (cache dropped), 1 MB sequential write | IOPS, IOPS, MB/s | SD / eMMC / NVMe / SATA carriers under database-style load |
| `ionity/io-net-loopback` | TCP loopback stream, 128 B RPC round trips, 32-connection 1 KB echo fan-out | MB/s, RPC/s, Messages/s | Host network stack in the shape of an MQTT broker |

Every profile prints a single `IONITY_RESULT:` line that the engine parses, plus a human-readable breakdown in the test log. Sources are embedded in each profile's `install.sh` (see `ob-cache/test-profiles/ionity/`).

## Ionity suites

| Suite | Runs | Offline | Typical use |
|---|---|---|---|
| `ionity/quick-check` | IO-Core, IO-Mem Triad, Telemetry ingest, JSON small | yes | First number from any machine, image sanity check |
| `ionity/edge-node` | IO-Core (1 + all cores), IO-Mem Copy/Triad, Thermal 3 min, Latency p99/max, Storage fsync/rand-read | yes | Raspberry Pi, Radxa ROCK, Orange Pi, Jetson, Intel N-series |
| `ionity/iot-gateway` | Telemetry (all), JSON (all), HMAC/SHA-256/PBKDF2, Net RPC/fan-out, Latency p99 | yes | Telemetry gateways, RMS collectors |
| `ionity/power-thermal` | IO-Core, Thermal 3 min, Thermal 10 min, IO-Core again | yes | Enclosure, heatsink and LiFePO4/solar power-budget validation |
| `ionity/ai-edge` | IO-AI-MatMul + TensorFlow Lite MobileNet/SqueezeNet, ONNX ResNet50-INT8/YOLOv4/SR, NCNN, MNN, Llama.cpp granite-3B, Whisper.cpp base | no | Hailo / NPU hosts, CPU inference boxes |
| `ionity/storage` | IO-Storage-Edge + fio direct 4K/1M, SQLite Speedtest, LevelDB fillsync/readrandom, RocksDB fillsync/readwhilewriting | no | SATA HATs, CM4 carriers, industrial SSDs |
| `ionity/timeseries-db` | IO-Telemetry-SQLite + pgbench s100, SQLite, InfluxDB 4/64 streams, ClickHouse, Apache IoTDB | no | TimescaleDB / PostgreSQL back-ends |
| `ionity/server-rms` | IO-Net-Loopback, IO-Crypto + nginx, Redis, Memcached, pgbench, OpenSSL, Zstd, stress-ng | no | RMS servers, brokers, API hosts |
| `ionity/workstation-design` | IO-Core, IO-Mem + Blender BMW27/Classroom, Embree Crown, OIDN, kernel defconfig build, 7-Zip, PyBench | no | KiCad / CAD / CAM / firmware build desks |
| `ionity/full-spectrum` | Every Ionity profile in every configuration (32 results) | yes | Reference publication run for a device |

Suites marked *no* use upstream OpenBenchmarking.org test profiles that download their workloads on first install; they are pinned to the exact upstream versions bundled in `ob-cache/` so the argument strings stay valid.

## Installation

Ionity Bench runs anywhere the Phoronix Test Suite runs: Linux, BSD, macOS, Solaris and Windows, on x86_64, AArch64 / ARM, RISC-V and POWER.

**Requirements:** PHP 7.4+ CLI (with DOM, Zip and PCRE), a C compiler (`gcc` or `clang`) and Python 3 for the Ionity profiles.

```console
# Debian / Ubuntu / Raspberry Pi OS
sudo apt install php-cli php-xml php-zip build-essential python3 git
git clone https://github.com/Ionity-Global/ionity-bench.git
cd ionity-bench
./ionity-bench quick-check
```

```console
# Fedora / RHEL
sudo dnf install php-cli php-xml php-zip gcc make python3 git
```

Optionally install system-wide with `sudo ./install-sh` (installs as `phoronix-test-suite`; copy `ionity-bench` to `/usr/local/bin` next to it). On Windows use `ionity-bench.bat`; it bootstraps PHP the same way `phoronix-test-suite.bat` does.

## Usage

```console
./ionity-bench                         # Banner, suites and profiles shipped in this release
./ionity-bench quick-check             # == phoronix-test-suite benchmark ionity/quick-check
./ionity-bench io-thermal-sustain      # Any ionity/io-* profile by short name
./ionity-bench benchmark ionity/edge-node pts/coremark   # Anything the engine accepts
./ionity-bench info ionity/io-core     # Options, scale and description of a profile
./ionity-bench list-saved-results      # Results are stored under ~/.phoronix-test-suite/test-results/
./ionity-bench result-file-to-pdf <result>   # Ionity-branded PDF export
```

Unattended runs use the engine's batch mode:

```console
./ionity-bench batch-setup                                  # once, answer the prompts
TEST_RESULTS_NAME=rock5b-rev1 TEST_RESULTS_IDENTIFIER=radxa-rock5b-8gb \
./ionity-bench batch-benchmark ionity/edge-node
```

Useful environment variables (all upstream): `FORCE_TIMES_TO_RUN=1` for a quick pass, `MONITOR=cpu.temp,cpu.freq,sys.power` to log sensors alongside `io-thermal-sustain`, `PRESET_OPTIONS_VALUES="io-core.threads=1"` to pre-answer option prompts by value (`PRESET_OPTIONS` matches the displayed option name instead).

The full engine manual is in [`documentation/`](documentation/) and the Ionity-specific guide in [`documentation/ionity-bench.md`](documentation/ionity-bench.md).

## Repository layout

```
ionity-bench/
├── ionity-bench, ionity-bench.bat        Ionity launchers (wrap phoronix-test-suite)
├── phoronix-test-suite(.bat)             Upstream engine launcher, unchanged
├── pts-core/                             Engine (GPL-3.0-or-later)
│   ├── pts-core.php                      + IONITY_BENCH_* defines, program_title()
│   ├── commands/ionity.php               + `ionity` overview command
│   ├── objects/pts_openbenchmarking.php  + `ionity` on-disk repository namespace
│   └── static/                           + Ionity logo, result viewer palette, desktop entry
├── ob-cache/
│   ├── test-profiles/ionity/io-*/        Ionity test profiles (self-contained)
│   ├── test-suites/ionity/*/             Ionity suites
│   └── test-profiles|test-suites/pts/    Upstream OpenBenchmarking.org cache
├── documentation/                        Upstream manual + ionity-bench.md
├── COPYING                               GNU GPL v3
├── NOTICE-IONITY.md                      Ionity attribution, trademark and Policy 986 AED notice
└── AUTHORS, ChangeLog                    Upstream credits (preserved)
```

## Licensing

* **Code** - Ionity Bench is a derivative work of the Phoronix Test Suite and is distributed under the same **GNU General Public License v3.0 or later** ([`COPYING`](COPYING)). All Ionity modifications and the Ionity test profiles are released under GPL-3.0-or-later. Phoronix Test Suite is Copyright (C) 2008-2026 Phoronix Media / Michael Larabel; see [`AUTHORS`](AUTHORS).
* **Brand** - The names *Ionity*, *Ionity Bench*, *AEDi* and *IO // WAY*, the Ionity Global logo and related identity media are trademarks and copyright of Ionity (Pty) Ltd (TM2), **All Rights Reserved**, and are **not** licensed under the GPL. Redistributions that modify the engine or profiles must not present themselves as official Ionity releases. See [`NOTICE-IONITY.md`](NOTICE-IONITY.md).
* **Governance** - [Policy 986 AED](https://www.ionity.today/license.html) governs Ionity's internal and external relations by default. Documentation authored by Ionity in this repository is CC BY-NC-SA 4.0 where stated.
* *Phoronix Test Suite*, *Phoromatic* and *OpenBenchmarking.org* are trademarks of Phoronix Media. *Ionity* here refers exclusively to www.ionity.today and is not affiliated with the European EV-charging network at ionity.com.

## Upstream

This repository tracks [phoronix-test-suite/phoronix-test-suite](https://github.com/phoronix-test-suite/phoronix-test-suite). Engine fixes should go upstream first; Ionity-specific changes stay in the files listed above so that `git merge upstream/master` remains clean.

## Contact

| | |
|---|---|
| Ionity Bench & AI | ai@ionity.today |
| General | info@ionity.today · johan@ionity.today |
| Phone | +27 646 999 877 |
| Web | https://www.ionity.today · https://www.ionity.co.za · https://www.ionity.live |
| Author | Johan Wilhelm van Antwerp · Founder, Technical Lead & Architect · ORCID [0009-0005-7181-0347](https://orcid.org/0009-0005-7181-0347) · Centurion, Gauteng, South Africa |

---
*(c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd — All Rights Reserved — TM2 · Policy 986 AED · IONITY GLOBAL (Pty) Ltd 2026/276325/07 · Building Tomorrow, Today. · Anything is Possible with God.*
