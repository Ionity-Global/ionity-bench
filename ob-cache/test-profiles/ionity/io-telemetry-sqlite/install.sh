#!/bin/sh
# Ionity Bench test profile installer - self-contained, no network downloads required.
# (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI | Policy 986 AED | GPL-3.0-or-later

cat > io-telemetry.py <<'IONITY_EOF'
#!/usr/bin/env python3
"""Ionity Bench - IO-Telemetry-SQLite

IoT telemetry ingest / query workload on SQLite (Python standard library only).
Copyright (C) 2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI. GPL-3.0-or-later.

Models an edge gateway or RMS node buffering sensor readings locally:
  * 256 simulated devices, each reading = timestamp, temperature, humidity, bus
    voltage, current, RSSI and a small JSON payload (as a real gateway would store it)
  * WAL journal, synchronous=NORMAL, batched transactions of 1000 rows
  * ingest  -> rows inserted per second
  * query   -> time-window aggregate queries per second (per-device min/avg/max over
               the last N minutes, plus a 5-minute bucket roll-up)
  * mixed   -> interleaved ingest + query, rows+queries per second

Usage: io-telemetry.py <ingest|query|mixed> [rows]
"""
import json
import os
import random
import sqlite3
import sys
import time

DEVICES = 256
BATCH = 1000


def make_db(path):
    if os.path.exists(path):
        os.remove(path)
    for suffix in ("-wal", "-shm"):
        if os.path.exists(path + suffix):
            os.remove(path + suffix)
    con = sqlite3.connect(path, isolation_level=None)
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("PRAGMA synchronous=NORMAL")
    con.execute("PRAGMA temp_store=MEMORY")
    con.execute("PRAGMA cache_size=-32768")
    con.execute(
        """CREATE TABLE telemetry (
            id INTEGER PRIMARY KEY,
            device_id INTEGER NOT NULL,
            ts INTEGER NOT NULL,
            temp_c REAL, humidity REAL, bus_v REAL, current_a REAL, rssi INTEGER,
            payload TEXT NOT NULL)"""
    )
    con.execute("CREATE INDEX idx_dev_ts ON telemetry(device_id, ts)")
    con.execute("CREATE INDEX idx_ts ON telemetry(ts)")
    return con


def gen_rows(rng, start_ts, count):
    ts = start_ts
    rows = []
    for i in range(count):
        dev = i % DEVICES
        if dev == 0:
            ts += 1
        temp = 18.0 + rng.random() * 30.0
        hum = 20.0 + rng.random() * 70.0
        volt = 12.0 + rng.random() * 2.4
        cur = rng.random() * 8.0
        rssi = -40 - rng.randrange(0, 60)
        payload = json.dumps(
            {"d": dev, "t": round(temp, 2), "h": round(hum, 1), "v": round(volt, 3),
             "i": round(cur, 3), "r": rssi, "f": rng.randrange(0, 4), "seq": i},
            separators=(",", ":"),
        )
        rows.append((dev, ts, temp, hum, volt, cur, rssi, payload))
    return rows, ts


def ingest(con, rows):
    cur = con.cursor()
    t0 = time.perf_counter()
    for i in range(0, len(rows), BATCH):
        cur.execute("BEGIN")
        cur.executemany(
            "INSERT INTO telemetry(device_id, ts, temp_c, humidity, bus_v, current_a, rssi, payload) VALUES (?,?,?,?,?,?,?,?)",
            rows[i:i + BATCH],
        )
        cur.execute("COMMIT")
    return time.perf_counter() - t0


def run_queries(con, rng, last_ts, count=None, seconds=None):
    """Run `count` queries, or as many as fit in `seconds`. Returns (elapsed, queries, rows)."""
    cur = con.cursor()
    sink = 0
    done = 0
    t0 = time.perf_counter()
    deadline = t0 + seconds if seconds else None
    while True:
        dev = rng.randrange(0, DEVICES)
        window = rng.choice((60, 300, 900))
        if done % 10 == 9:
            # Dashboard roll-up: 1-minute buckets over the last 5 minutes, all devices
            cur.execute(
                "SELECT (ts/60)*60 AS bucket, AVG(temp_c), MAX(current_a), COUNT(*) FROM telemetry "
                "WHERE ts >= ? GROUP BY bucket",
                (last_ts - 300,),
            )
        else:
            # Device detail: min/avg/max over a recent window (uses idx_dev_ts)
            cur.execute(
                "SELECT MIN(temp_c), AVG(temp_c), MAX(temp_c), AVG(bus_v), COUNT(*) FROM telemetry "
                "WHERE device_id = ? AND ts >= ?",
                (dev, last_ts - window),
            )
        sink += len(cur.fetchall())
        done += 1
        if count is not None and done >= count:
            break
        if deadline is not None and time.perf_counter() >= deadline:
            break
    return time.perf_counter() - t0, done, sink


def main():
    mode = (sys.argv[1] if len(sys.argv) > 1 else "ingest").lower()
    rows_total = int(sys.argv[2]) if len(sys.argv) > 2 else 500000
    rng = random.Random(986)
    db = os.path.join(os.getcwd(), "ionity-telemetry.db")
    con = make_db(db)

    print("Ionity Bench IO-Telemetry-SQLite")
    print(f"SQLite {sqlite3.sqlite_version}  Mode: {mode}  Devices: {DEVICES}  Batch: {BATCH}  DB: {db}")

    base_ts = 1_800_000_000
    if mode == "ingest":
        rows, last_ts = gen_rows(rng, base_ts, rows_total)
        secs = ingest(con, rows)
        print(f"Inserted {len(rows)} rows in {secs:.3f} s")
        print(f"IONITY_RESULT: {len(rows) / secs:.1f}")
    elif mode == "query":
        rows, last_ts = gen_rows(rng, base_ts, rows_total)
        secs = ingest(con, rows)
        print(f"Pre-loaded {len(rows)} rows in {secs:.3f} s")
        con.execute("ANALYZE")
        qsecs, queries, sink = run_queries(con, rng, last_ts, seconds=15.0)
        print(f"Ran {queries} window queries in {qsecs:.3f} s (rows fetched {sink})")
        print(f"IONITY_RESULT: {queries / qsecs:.1f}")
    elif mode == "mixed":
        rows, last_ts = gen_rows(rng, base_ts, rows_total // 2)
        secs = ingest(con, rows)
        print(f"Pre-loaded {len(rows)} rows in {secs:.3f} s")
        more, last_ts = gen_rows(rng, last_ts, rows_total // 2)
        ops = 0
        t0 = time.perf_counter()
        for i in range(0, len(more), BATCH):
            ingest(con, more[i:i + BATCH])
            ops += BATCH
            _, q, sink = run_queries(con, rng, last_ts, count=10)
            ops += q
        msecs = time.perf_counter() - t0
        print(f"Mixed phase: {ops} operations in {msecs:.3f} s")
        print(f"IONITY_RESULT: {ops / msecs:.1f}")
    else:
        print("usage: io-telemetry.py <ingest|query|mixed> [rows]", file=sys.stderr)
        sys.exit(1)

    size = os.path.getsize(db) / 1048576.0
    con.close()
    print(f"Database size: {size:.1f} MiB")
    for suffix in ("", "-wal", "-shm"):
        try:
            os.remove(db + suffix)
        except OSError:
            pass


if __name__ == "__main__":
    main()
IONITY_EOF

PYTHON_BIN=$(command -v python3 || command -v python)
if [ -z "$PYTHON_BIN" ]; then echo "python3 not found" ; echo 1 > ~/install-exit-status; exit 1; fi
"$PYTHON_BIN" -c "import ast,sys; ast.parse(open('io-telemetry.py').read())"
echo $? > ~/install-exit-status

echo "#!/bin/sh
$PYTHON_BIN -I io-telemetry.py \$@ 500000 > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > io-telemetry-sqlite
chmod +x io-telemetry-sqlite
