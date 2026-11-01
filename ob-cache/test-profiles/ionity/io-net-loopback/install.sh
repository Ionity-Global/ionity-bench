#!/bin/sh
# Ionity Bench test profile installer - self-contained, no network downloads required.
# (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI | Policy 986 AED | GPL-3.0-or-later

cat > io-net.py <<'IONITY_EOF'
#!/usr/bin/env python3
"""Ionity Bench - IO-Net-Loopback

TCP loopback networking stack throughput and small-message round trips (standard library
only). Isolates the host's socket / scheduler path from the physical NIC, which is what
limits brokers, gateways and RMS collectors running many local services.
Copyright (C) 2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI. GPL-3.0-or-later.

  * stream   -> 256 KiB sends over one TCP connection          -> MB/s
  * rpc      -> 128-byte request / 128-byte reply ping-pong    -> round trips per second
  * fanout   -> 32 concurrent connections, 1 KiB messages,
                echo server with selectors (MQTT broker shape) -> messages per second

Usage: io-net.py <stream|rpc|fanout> [seconds]
"""
import selectors
import socket
import sys
import threading
import time


def serve_echo(srv, stop, chunk=1 << 16):
    sel = selectors.DefaultSelector()
    srv.setblocking(False)
    sel.register(srv, selectors.EVENT_READ)
    conns = []
    while not stop.is_set():
        for key, _ in sel.select(timeout=0.2):
            if key.fileobj is srv:
                c, _ = srv.accept()
                c.setblocking(False)
                c.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                sel.register(c, selectors.EVENT_READ)
                conns.append(c)
            else:
                try:
                    data = key.fileobj.recv(chunk)
                except OSError:
                    data = b""
                if not data:
                    sel.unregister(key.fileobj)
                    key.fileobj.close()
                else:
                    key.fileobj.sendall(data)
    for c in conns:
        try:
            c.close()
        except OSError:
            pass


def serve_sink(srv, stop, chunk=1 << 18):
    srv.settimeout(0.5)
    while not stop.is_set():
        try:
            c, _ = srv.accept()
        except socket.timeout:
            continue
        with c:
            while not stop.is_set():
                if not c.recv(chunk):
                    break


def client(port):
    c = socket.create_connection(("127.0.0.1", port))
    c.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    return c


def recv_exact(sock, n):
    buf = bytearray()
    while len(buf) < n:
        part = sock.recv(n - len(buf))
        if not part:
            raise ConnectionError("peer closed")
        buf += part
    return buf


def main():
    mode = (sys.argv[1] if len(sys.argv) > 1 else "stream").lower()
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 10.0
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(64)
    port = srv.getsockname()[1]
    stop = threading.Event()

    print("Ionity Bench IO-Net-Loopback")
    print(f"Python {sys.version.split()[0]}  Mode: {mode}  Port: {port}  Window: {seconds:.0f} s")

    if mode == "stream":
        t = threading.Thread(target=serve_sink, args=(srv, stop), daemon=True)
        t.start()
        c = client(port)
        payload = b"\xA5" * (1 << 18)
        sent = 0
        t0 = time.perf_counter()
        deadline = t0 + seconds
        while time.perf_counter() < deadline:
            for _ in range(8):
                c.sendall(payload)
                sent += len(payload)
        secs = time.perf_counter() - t0
        c.close()
        print(f"Streamed {sent / 1e6:.0f} MB in {secs:.3f} s")
        print(f"IONITY_RESULT: {sent / 1e6 / secs:.1f}")
    elif mode == "rpc":
        t = threading.Thread(target=serve_echo, args=(srv, stop), daemon=True)
        t.start()
        c = client(port)
        msg = b"\x5A" * 128
        trips = 0
        t0 = time.perf_counter()
        deadline = t0 + seconds
        while time.perf_counter() < deadline:
            for _ in range(64):
                c.sendall(msg)
                recv_exact(c, 128)
                trips += 1
        secs = time.perf_counter() - t0
        c.close()
        print(f"{trips} round trips in {secs:.3f} s  avg RTT {secs / trips * 1e6:.1f} us")
        print(f"IONITY_RESULT: {trips / secs:.1f}")
    elif mode == "fanout":
        t = threading.Thread(target=serve_echo, args=(srv, stop), daemon=True)
        t.start()
        n_conn = 32
        conns = [client(port) for _ in range(n_conn)]
        msg = b"\x3C" * 1024
        total = [0]
        lock = threading.Lock()

        def pump(c, deadline):
            local = 0
            while time.perf_counter() < deadline:
                for _ in range(16):
                    c.sendall(msg)
                    recv_exact(c, 1024)
                    local += 1
            with lock:
                total[0] += local

        t0 = time.perf_counter()
        deadline = t0 + seconds
        workers = [threading.Thread(target=pump, args=(c, deadline)) for c in conns]
        for w in workers:
            w.start()
        for w in workers:
            w.join()
        secs = time.perf_counter() - t0
        for c in conns:
            c.close()
        print(f"{total[0]} x 1 KiB echo messages over {n_conn} connections in {secs:.3f} s")
        print(f"IONITY_RESULT: {total[0] / secs:.1f}")
    else:
        print("usage: io-net.py <stream|rpc|fanout> [seconds]", file=sys.stderr)
        sys.exit(1)
    stop.set()
    srv.close()


if __name__ == "__main__":
    main()
IONITY_EOF

PYTHON_BIN=$(command -v python3 || command -v python)
if [ -z "$PYTHON_BIN" ]; then echo "python3 not found" ; echo 1 > ~/install-exit-status; exit 1; fi
"$PYTHON_BIN" -c "import ast,sys; ast.parse(open('io-net.py').read())"
echo $? > ~/install-exit-status

echo "#!/bin/sh
$PYTHON_BIN -I io-net.py \$@ 10 > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > io-net-loopback
chmod +x io-net-loopback
