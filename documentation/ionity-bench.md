<!--
========================================================================================
AEDI - IONITY GLOBAL - IONITY BENCH - USER & DEVELOPER GUIDE
Author: Johan Wilhelm van Antwerp | Ionity (Pty) Ltd | AEDI
Document ID: DOC-2026-11-003 | Version: 1.0 | Updated: 2026-11-01 SAST
Governance: Policy 986 AED | Code: GPL-3.0-or-later | Text: CC BY-NC-SA 4.0
(c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - All Rights Reserved - TM2
Classification: PUBLIC | Building Tomorrow, Today.
========================================================================================
-->

# Ionity Bench — User & Developer Guide

Ionity Bench 1.0.0 "Centurion" on Phoronix Test Suite 10.8.6.
For the complete engine manual see [`phoronix-test-suite.md`](phoronix-test-suite.md); this guide covers only what Ionity adds.

## 1. Concepts

| Term | Meaning |
|---|---|
| **Engine** | The unmodified Phoronix Test Suite core (`pts-core/`). Everything upstream still works. |
| **`ionity/` repository** | An on-disk namespace next to `local/`, `pts/`, `system/`, `git/`. It needs no OpenBenchmarking.org index; the engine resolves `ionity/<name>` straight from `ob-cache/test-profiles/ionity/<name>/` (copied to `~/.phoronix-test-suite/test-profiles/ionity/` on first run). |
| **Ionity profile** | A test profile authored by Ionity. All ten are self-contained: the C or Python source is embedded in `install.sh`, there is no `downloads.xml`, and the only external dependencies are `build-utilities` (a C compiler) or `python`. |
| **Ionity suite** | A `suite-definition.xml` that lists profiles with pinned arguments. Suites that mix in upstream `pts/` tests pin them to the versions bundled in `ob-cache/`. |
| **ION Points** | The IO-Core score: completed work units per second across the selected threads. One work unit is roughly 3.2 million mixed ALU / FP / branch operations. |

## 2. Running

```console
./ionity-bench                         # banner, suites, profiles
./ionity-bench quick-check             # suite short names: quick-check edge-node iot-gateway power-thermal
                                       #   ai-edge storage timeseries-db server-rms workstation-design full-spectrum
./ionity-bench io-mem                  # any ionity/io-* profile by short name (prompts for options)
./ionity-bench benchmark ionity/io-mem pts/stream     # anything the engine accepts
```

`ionity-bench` is a thin POSIX shell wrapper: it resolves the sibling `phoronix-test-suite` launcher (or a system install), exports `IONITY_BENCH=1`, expands the short names above and `exec`s the engine. `ionity-bench.bat` does the same on Windows.

### 2.1 Unattended / CI

```console
./ionity-bench batch-setup             # once per machine; disable prompts, decide on uploads
TEST_RESULTS_NAME=gw-rev3 TEST_RESULTS_IDENTIFIER=rpi5-8gb-sata \
FORCE_TIMES_TO_RUN=3 ./ionity-bench batch-benchmark ionity/iot-gateway
./ionity-bench result-file-to-pdf gw-rev3
```

Pre-answer option prompts for single profiles with `PRESET_OPTIONS_VALUES` (matches the option *value*) or `PRESET_OPTIONS` (matches the displayed option *name*):

```console
PRESET_OPTIONS_VALUES="io-core.threads=1;io-thermal-sustain.duration=600" \
./ionity-bench batch-benchmark ionity/io-core ionity/io-thermal-sustain

PRESET_OPTIONS="io-storage-edge.workload=1MB Sequential Write" ./ionity-bench benchmark ionity/io-storage-edge
```

Option identifiers and values: `io-core.threads` (0 all, 1, 4) · `io-mem.kernel` (Copy Scale Add Triad) · `io-thermal-sustain.duration` (60 180 600) · `io-latency-rt.metric` (max p99 avg) · `io-ai-matmul.precision` (fp32 int8) · `io-telemetry-sqlite.workload` (ingest query mixed) · `io-json-mqtt.payload` (small large sparkplug) · `io-crypto-edge.algorithm` (sha256 sha512 blake2b hmac-small pbkdf2) · `io-storage-edge.workload` (fsync-write rand-read seq-write) · `io-net-loopback.pattern` (stream rpc fanout).

### 2.2 Sensors alongside a run

```console
MONITOR=cpu.temp,cpu.freq,sys.power ./ionity-bench benchmark ionity/power-thermal
```

The engine's `system_monitor` module records the sensors and attaches them to the result file; combined with `io-thermal-sustain`'s per-second GFLOPS log this gives a full throttling curve.

### 2.3 Where things land

| | Path |
|---|---|
| Results | `~/.phoronix-test-suite/test-results/<name>/composite.xml` (+ HTML viewer) |
| Installed Ionity tests | `~/.phoronix-test-suite/installed-tests/ionity/<name>/` (binary, script, `ionity-*.db` / `.bin` scratch files are removed after each run) |
| Logs of the last run | `~/.phoronix-test-suite/test-results/<name>/test-logs/` |
| Configuration | `~/.phoronix-test-suite/user-config.xml` |

Result XML carries `<TestClient>Ionity Bench v1.0.0 (Phoronix Test Suite v10.8.6)</TestClient>` and `<IonityBench>Ionity Bench 1.0.0 (Centurion)</IonityBench>` so Ionity results remain identifiable after upload or merge.

## 3. Interpreting the Ionity profiles

* **IO-Core** — compare *Single Core* across devices for latency-bound control code, *All CPU Cores* for throughput. Deviation above ~5% usually means frequency scaling or a noisy host; run with `FORCE_TIMES_TO_RUN=5`.
* **IO-Mem** — Triad is the headline figure. On SBCs the Copy/Triad ratio shows whether the memory controller or the core's load/store path is the limit.
* **IO-Thermal-Sustain** — 100% = no throttling. Anything under ~85% at 10 minutes means the enclosure or heatsink needs work before field deployment. The log also lists SoC temperature start/end on Linux.
* **IO-Latency-RT** — p99 under 200 µs is comfortable for 1 kHz loops on a standard kernel; max is dominated by the worst interrupt storm. A `PREEMPT_RT` kernel should show p99.9 and max collapsing.
* **IO-AI-MatMul** — INT8 GOPS vs FP32 GFLOPS shows whether the CPU has usable integer dot-product paths; a ratio near 1.0 means quantisation buys nothing on this CPU and an NPU (Hailo) is the right call.
* **IO-Telemetry-SQLite** — ingest rows/s is the gateway's buffer ceiling; query/s is dashboard responsiveness on a 500k-row store; mixed is the realistic steady state.
* **IO-JSON-MQTT** — small messages/s approximates broker-bridge throughput per core; large and Sparkplug stress allocation and nested structures.
* **IO-Crypto-Edge** — SHA-256 MB/s tracks OTA verification time; HMAC messages/s tracks signed telemetry rate; PBKDF2 derivations/s tracks onboarding and credential rotation cost.
* **IO-Storage-Edge** — fsync IOPS is the one that separates SD cards (tens) from industrial eMMC/NVMe (thousands). rand-read IOPS is database read latency; seq-write MB/s is camera and log rollover.
* **IO-Net-Loopback** — RPC round trips/s and fan-out messages/s are the host's ceiling for a local broker + collector pair before the NIC is even involved.

## 4. Adding an Ionity profile

1. Create `ob-cache/test-profiles/ionity/<name>/` with `test-definition.xml`, `results-definition.xml` and `install.sh`.
2. Embed the source in `install.sh` with a quoted heredoc (`<<'IONITY_EOF'`), compile or syntax-check it, write `~/install-exit-status`, and emit a runner script named exactly `<name>` that writes to `$LOG_FILE` and `~/test-exit-status` (see any existing profile).
3. Print one `IONITY_RESULT: <number>` line. If different options have different scales, add one `<ResultsParser>` per option with `<MatchToTestArguments>` and `<ResultScale>` (see `io-ai-matmul`).
4. Set `<ExternalDependencies>` to `build-utilities` and/or `python`; keep `<SupportedPlatforms>` honest.
5. Add it to `ionity/full-spectrum` and any suite where it belongs; run `./ionity-bench info ionity/<name>` and a `FORCE_TIMES_TO_RUN=1` benchmark.

Reference versions of the embedded sources also live in the git history of this repository and are reproduced by `install.sh`; there is no separate build step.

## 5. Adding an Ionity suite

Create `ob-cache/test-suites/ionity/<name>/suite-definition.xml`. Use `<Arguments>` + `<Description>` to pin a configuration, or `<Mode>BATCH</Mode>` to run every option. When pinning an upstream `pts/` test, pin its version too (`pts/fio-2.2.0`) and copy the exact argument string the engine composes — the Python helper used to generate the shipped suites is documented in the commit history.

## 6. Keeping in sync with upstream

```console
git remote add upstream https://github.com/phoronix-test-suite/phoronix-test-suite.git
git fetch upstream
git merge upstream/master
```

Ionity touches a small, deliberate set of engine files (listed in `README.md` → Repository layout). Conflicts, if any, are confined to those.

## 7. Licence summary

Code: GPL-3.0-or-later, same as upstream — see `COPYING`. Ionity marks and logo: All Rights Reserved, Policy 986 AED — see `NOTICE-IONITY.md`. This document: CC BY-NC-SA 4.0.

---
*(c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd — All Rights Reserved — TM2 · Policy 986 AED · https://www.ionity.today · ai@ionity.today*
