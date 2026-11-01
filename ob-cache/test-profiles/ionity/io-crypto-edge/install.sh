#!/bin/sh
# Ionity Bench test profile installer - self-contained, no network downloads required.
# (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI | Policy 986 AED | GPL-3.0-or-later

cat > io-crypto.py <<'IONITY_EOF'
#!/usr/bin/env python3
"""Ionity Bench - IO-Crypto-Edge

Hashing / message-authentication throughput for TLS, OTA-update verification and
signed telemetry on edge devices (Python standard library only).
Copyright (C) 2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI. GPL-3.0-or-later.

  * sha256   -> SHA-256 over 1 MiB blocks (OTA image verification, TLS record MAC)
  * sha512   -> SHA-512 over 1 MiB blocks
  * blake2b  -> BLAKE2b over 1 MiB blocks (modern firmware signing)
  * hmac-small -> HMAC-SHA256 over 256-byte messages (signed MQTT telemetry)
  * pbkdf2   -> PBKDF2-HMAC-SHA256, 100k iterations (device credential derivation)
Result: MB/s for block modes, messages/s for hmac-small, derivations/s for pbkdf2.

Usage: io-crypto.py <sha256|sha512|blake2b|hmac-small|pbkdf2> [seconds]
"""
import hashlib
import hmac
import os
import sys
import time


def main():
    algo = (sys.argv[1] if len(sys.argv) > 1 else "sha256").lower()
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 10.0
    key = b"ionity-policy-986-aed-demo-key-not-secret"
    print("Ionity Bench IO-Crypto-Edge")
    print(f"Python {sys.version.split()[0]}  OpenSSL: {getattr(hashlib, 'openssl_version', 'n/a') if hasattr(hashlib, 'openssl_version') else 'builtin'}  Algorithm: {algo}  Window: {seconds:.0f} s")

    t0 = time.perf_counter()
    deadline = t0 + seconds
    if algo in ("sha256", "sha512", "blake2b"):
        block = os.urandom(1 << 20)
        ctor = getattr(hashlib, algo)
        done = 0
        digest = b""
        while time.perf_counter() < deadline:
            for _ in range(8):
                digest = ctor(block).digest()
                done += 1
        secs = time.perf_counter() - t0
        mb = done * len(block) / 1e6
        print(f"Hashed {done} x 1 MiB blocks in {secs:.3f} s (last digest {digest[:8].hex()})")
        print(f"IONITY_RESULT: {mb / secs:.1f}")
    elif algo == "hmac-small":
        msgs = [os.urandom(256) for _ in range(1024)]
        done = 0
        tag = b""
        while time.perf_counter() < deadline:
            for m in msgs:
                tag = hmac.new(key, m, hashlib.sha256).digest()
            done += len(msgs)
        secs = time.perf_counter() - t0
        print(f"Authenticated {done} x 256 B messages in {secs:.3f} s (last tag {tag[:8].hex()})")
        print(f"IONITY_RESULT: {done / secs:.1f}")
    elif algo == "pbkdf2":
        done = 0
        dk = b""
        while time.perf_counter() < deadline or done < 3:
            dk = hashlib.pbkdf2_hmac("sha256", b"device-%d" % done, key, 100000, 32)
            done += 1
        secs = time.perf_counter() - t0
        print(f"Derived {done} keys (100k iterations) in {secs:.3f} s (last {dk[:8].hex()})")
        print(f"IONITY_RESULT: {done / secs:.3f}")
    else:
        print("usage: io-crypto.py <sha256|sha512|blake2b|hmac-small|pbkdf2> [seconds]", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
IONITY_EOF

PYTHON_BIN=$(command -v python3 || command -v python)
if [ -z "$PYTHON_BIN" ]; then echo "python3 not found" ; echo 1 > ~/install-exit-status; exit 1; fi
"$PYTHON_BIN" -c "import ast,sys; ast.parse(open('io-crypto.py').read())"
echo $? > ~/install-exit-status

echo "#!/bin/sh
$PYTHON_BIN -I io-crypto.py \$@ 10 > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > io-crypto-edge
chmod +x io-crypto-edge
