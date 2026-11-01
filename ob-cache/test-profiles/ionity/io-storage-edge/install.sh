#!/bin/sh
# Ionity Bench test profile installer - self-contained, no network downloads required.
# (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI | Policy 986 AED | GPL-3.0-or-later

cat > io-storage.py <<'IONITY_EOF'
#!/usr/bin/env python3
"""Ionity Bench - IO-Storage-Edge

Storage behaviour that matters on SD cards, eMMC, NVMe HATs and SATA carriers
(Radxa SATA, Pi CM4 carriers): durable small writes, random reads and streaming writes.
Copyright (C) 2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI. GPL-3.0-or-later.

  * fsync-write -> 4 KiB random writes each followed by fsync() (SQLite/WAL-style
                   durable commits, log appends)         -> IOPS
  * rand-read   -> 4 KiB random reads across a 512 MiB file, page cache dropped
                   with posix_fadvise(DONTNEED) where supported -> IOPS
  * seq-write   -> 1 MiB sequential writes, fsync at end (camera / log roll, OTA) -> MB/s
The scratch file is created in the current directory (the test's install directory on
the device under test) and removed afterwards.

Usage: io-storage.py <fsync-write|rand-read|seq-write> [seconds]
"""
import os
import random
import sys
import time

FILE_MB = 512
PATH = os.path.join(os.getcwd(), "ionity-storage.bin")


def fill(path, mb):
    chunk = os.urandom(1 << 20)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
    for _ in range(mb):
        os.write(fd, chunk)
    os.fsync(fd)
    os.close(fd)


def drop_cache(fd):
    if hasattr(os, "posix_fadvise"):
        try:
            os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_DONTNEED)
        except OSError:
            pass


def main():
    mode = (sys.argv[1] if len(sys.argv) > 1 else "fsync-write").lower()
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 20.0
    rng = random.Random(986)
    st = os.statvfs(os.getcwd())
    free_mb = st.f_bavail * st.f_frsize / 1048576
    size_mb = FILE_MB if free_mb > FILE_MB * 2 else max(64, int(free_mb / 4))

    print("Ionity Bench IO-Storage-Edge")
    print(f"Mode: {mode}  Scratch: {PATH}  File: {size_mb} MiB  Free: {free_mb:.0f} MiB  Window: {seconds:.0f} s")

    try:
        if mode == "fsync-write":
            fill(PATH, size_mb)
            fd = os.open(PATH, os.O_RDWR)
            block = os.urandom(4096)
            blocks = size_mb * 256
            ops = 0
            t0 = time.perf_counter()
            deadline = t0 + seconds
            while time.perf_counter() < deadline:
                for _ in range(16):
                    os.pwrite(fd, block, rng.randrange(0, blocks) * 4096)
                    os.fsync(fd)
                    ops += 1
            secs = time.perf_counter() - t0
            os.close(fd)
            print(f"{ops} durable 4 KiB writes in {secs:.3f} s  avg latency {secs / ops * 1e6:.1f} us")
            print(f"IONITY_RESULT: {ops / secs:.1f}")
        elif mode == "rand-read":
            fill(PATH, size_mb)
            fd = os.open(PATH, os.O_RDONLY)
            drop_cache(fd)
            blocks = size_mb * 256
            ops = 0
            sink = 0
            t0 = time.perf_counter()
            deadline = t0 + seconds
            while time.perf_counter() < deadline:
                for _ in range(64):
                    sink += len(os.pread(fd, 4096, rng.randrange(0, blocks) * 4096))
                    ops += 1
                if ops % 4096 == 0:
                    drop_cache(fd)
            secs = time.perf_counter() - t0
            os.close(fd)
            print(f"{ops} random 4 KiB reads in {secs:.3f} s ({sink / 1e6:.1f} MB)")
            print(f"IONITY_RESULT: {ops / secs:.1f}")
        elif mode == "seq-write":
            chunk = os.urandom(1 << 20)
            written = 0
            t0 = time.perf_counter()
            deadline = t0 + seconds
            passes = 0
            while time.perf_counter() < deadline or passes == 0:
                fd = os.open(PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
                for _ in range(size_mb):
                    os.write(fd, chunk)
                    written += len(chunk)
                os.fsync(fd)
                os.close(fd)
                passes += 1
            secs = time.perf_counter() - t0
            print(f"Wrote {written / 1e6:.0f} MB sequentially in {passes} pass(es), {secs:.3f} s")
            print(f"IONITY_RESULT: {written / 1e6 / secs:.1f}")
        else:
            print("usage: io-storage.py <fsync-write|rand-read|seq-write> [seconds]", file=sys.stderr)
            sys.exit(1)
    finally:
        try:
            os.remove(PATH)
        except OSError:
            pass


if __name__ == "__main__":
    main()
IONITY_EOF

PYTHON_BIN=$(command -v python3 || command -v python)
if [ -z "$PYTHON_BIN" ]; then echo "python3 not found" ; echo 1 > ~/install-exit-status; exit 1; fi
"$PYTHON_BIN" -c "import ast,sys; ast.parse(open('io-storage.py').read())"
echo $? > ~/install-exit-status

echo "#!/bin/sh
$PYTHON_BIN -I io-storage.py \$@ 20 > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > io-storage-edge
chmod +x io-storage-edge
