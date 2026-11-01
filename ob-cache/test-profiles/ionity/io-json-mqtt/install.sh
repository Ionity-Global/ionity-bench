#!/bin/sh
# Ionity Bench test profile installer - self-contained, no network downloads required.
# (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI | Policy 986 AED | GPL-3.0-or-later

cat > io-json.py <<'IONITY_EOF'
#!/usr/bin/env python3
"""Ionity Bench - IO-JSON-MQTT

MQTT-style JSON telemetry encode / decode / validate throughput (standard library only).
Copyright (C) 2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI. GPL-3.0-or-later.

Every gateway, broker bridge and RMS back-end spends a large share of its CPU on
serialising and parsing small JSON messages. This bench round-trips realistic payloads:
  * small  -> single sensor reading (~180 bytes): topic routing, dumps, loads, schema check
  * large  -> batched uplink of 100 readings (~12 KB) as a device would send on reconnect
  * sparkplug -> Sparkplug-B style metric list with aliases and datatypes (~2 KB)
Result: messages processed per second (one message = encode + decode + validate).

Usage: io-json.py <small|large|sparkplug> [seconds]
"""
import json
import random
import sys
import time

REQUIRED = ("device", "ts", "metrics")


def reading(rng, i):
    return {
        "device": f"ion-edge-{i % 512:04d}",
        "ts": 1_800_000_000_000 + i * 1000,
        "seq": i,
        "metrics": {
            "temp_c": round(18 + rng.random() * 30, 2),
            "humidity": round(20 + rng.random() * 70, 1),
            "bus_v": round(12 + rng.random() * 2.4, 3),
            "current_a": round(rng.random() * 8, 3),
            "rssi": -40 - rng.randrange(0, 60),
        },
        "flags": {"online": True, "alarm": rng.random() < 0.02},
    }


def sparkplug(rng, i):
    names = ("Inputs/Temperature", "Inputs/Humidity", "Power/BusVoltage", "Power/Current",
             "Radio/RSSI", "System/Uptime", "System/FreeHeap", "Inputs/Door")
    return {
        "timestamp": 1_800_000_000_000 + i * 1000,
        "seq": i % 256,
        "metrics": [
            {"name": n, "alias": a, "timestamp": 1_800_000_000_000 + i * 1000,
             "dataType": "Float" if a < 5 else ("Int64" if a < 7 else "Boolean"),
             "value": (round(rng.random() * 100, 3) if a < 5 else (rng.randrange(0, 1 << 31) if a < 7 else rng.random() < 0.5))}
            for a, n in enumerate(names)
        ],
    }


def build(kind, rng, i):
    if kind == "small":
        return reading(rng, i)
    if kind == "large":
        return {"device": f"ion-gw-{i % 64:03d}", "ts": 1_800_000_000_000 + i * 1000,
                "metrics": [reading(rng, i * 100 + k)["metrics"] for k in range(100)]}
    if kind == "sparkplug":
        return sparkplug(rng, i)
    raise SystemExit("usage: io-json.py <small|large|sparkplug> [seconds]")


def validate(kind, obj):
    if kind == "sparkplug":
        return isinstance(obj["metrics"], list) and all("alias" in m and "value" in m for m in obj["metrics"])
    for k in REQUIRED:
        if k not in obj:
            return False
    m = obj["metrics"]
    if isinstance(m, dict):
        return -120 <= m["rssi"] <= 0 and 0 <= m["humidity"] <= 100
    return all(-120 <= r["rssi"] <= 0 for r in m)


def main():
    kind = (sys.argv[1] if len(sys.argv) > 1 else "small").lower()
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 10.0
    rng = random.Random(986)
    pool = [build(kind, rng, i) for i in range(256)]
    sample = json.dumps(pool[0], separators=(",", ":"))

    print("Ionity Bench IO-JSON-MQTT")
    print(f"Python {sys.version.split()[0]}  Payload: {kind}  Sample size: {len(sample)} bytes  Window: {seconds:.0f} s")

    dumps, loads = json.dumps, json.loads
    count, bad, size = 0, 0, 0
    t0 = time.perf_counter()
    deadline = t0 + seconds
    while True:
        for obj in pool:
            topic = "ionity/%s/telemetry" % (obj.get("device") or "spBv1.0/ionity/DDATA")
            wire = dumps(obj, separators=(",", ":")).encode()
            size += len(wire) + len(topic)
            back = loads(wire)
            if not validate(kind, back):
                bad += 1
            count += 1
        if time.perf_counter() >= deadline:
            break
    secs = time.perf_counter() - t0
    print(f"Messages: {count}  Invalid: {bad}  Wire bytes: {size}  Throughput: {size / secs / 1e6:.2f} MB/s")
    print(f"IONITY_RESULT: {count / secs:.1f}")


if __name__ == "__main__":
    main()
IONITY_EOF

PYTHON_BIN=$(command -v python3 || command -v python)
if [ -z "$PYTHON_BIN" ]; then echo "python3 not found" ; echo 1 > ~/install-exit-status; exit 1; fi
"$PYTHON_BIN" -c "import ast,sys; ast.parse(open('io-json.py').read())"
echo $? > ~/install-exit-status

echo "#!/bin/sh
$PYTHON_BIN -I io-json.py \$@ 10 > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > io-json-mqtt
chmod +x io-json-mqtt
