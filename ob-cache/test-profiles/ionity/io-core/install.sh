#!/bin/sh
# Ionity Bench test profile installer - self-contained, no network downloads required.
# (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI | Policy 986 AED | GPL-3.0-or-later

cat > io-core.c <<'IONITY_EOF'
/*
 * Ionity Bench - IO-Core
 * Mixed integer / floating-point / branch CPU kernel for edge-class processors.
 * Copyright (C) 2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI. GPL-3.0-or-later.
 *
 * Each worker runs a fixed "work unit" repeatedly for the measurement window:
 *   1. xorshift64* PRNG + FNV-1a hashing over a 16 KiB buffer      (integer / ALU)
 *   2. 16x16 complex-plane escape-time iteration (Mandelbrot)       (FP / FMA)
 *   3. odd-only sieve of Eratosthenes to 65536                      (branch / cache)
 * The score (ION Points) is completed work units per second across all workers;
 * one work unit is roughly 3.2 million mixed ALU / FP / branch operations.
 *
 * Usage: io-core <threads|0=all> [seconds]
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>

static volatile int g_stop = 0;

static double now_sec(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static inline uint64_t xorshift64s(uint64_t *s)
{
	uint64_t x = *s;
	x ^= x >> 12; x ^= x << 25; x ^= x >> 27;
	*s = x;
	return x * 0x2545F4914F6CDD1DULL;
}

static uint64_t kernel_int(uint64_t *seed, uint8_t *buf, size_t n)
{
	for(size_t i = 0; i < n; i += 8)
	{
		uint64_t v = xorshift64s(seed);
		memcpy(buf + i, &v, 8);
	}
	uint64_t h = 0xcbf29ce484222325ULL;
	for(size_t i = 0; i < n; i++)
	{
		h ^= buf[i];
		h *= 0x100000001b3ULL;
	}
	return h;
}

static uint32_t kernel_fp(double cx0, double cy0)
{
	uint32_t total = 0;
	for(int py = 0; py < 16; py++)
	{
		for(int px = 0; px < 16; px++)
		{
			double cx = cx0 + px * 0.01, cy = cy0 + py * 0.01;
			double zx = 0, zy = 0;
			int it = 0;
			while(it < 256 && zx * zx + zy * zy < 4.0)
			{
				double t = zx * zx - zy * zy + cx;
				zy = 2.0 * zx * zy + cy;
				zx = t;
				it++;
			}
			total += it;
		}
	}
	return total;
}

static uint32_t kernel_branch(uint8_t *sieve, uint32_t limit)
{
	memset(sieve, 1, limit / 2);
	uint32_t count = 1; /* 2 */
	for(uint32_t i = 3; i < limit; i += 2)
	{
		if(sieve[i / 2])
		{
			count++;
			for(uint32_t j = i * i; j < limit; j += 2 * i)
				sieve[j / 2] = 0;
		}
	}
	return count;
}

typedef struct { uint64_t units; uint64_t sink; int id; } worker_t;

static void *worker(void *arg)
{
	worker_t *w = (worker_t *) arg;
	uint64_t seed = 0x9E3779B97F4A7C15ULL ^ (uint64_t)(w->id + 1);
	uint8_t *buf = malloc(16384);
	uint8_t *sieve = malloc(65536 / 2);
	uint64_t sink = 0, units = 0;
	while(!g_stop)
	{
		sink += kernel_int(&seed, buf, 16384);
		sink += kernel_fp(-0.745 + (w->id * 0.001), 0.1);
		sink += kernel_branch(sieve, 65536);
		units++;
	}
	w->units = units;
	w->sink = sink;
	free(buf);
	free(sieve);
	return NULL;
}

int main(int argc, char **argv)
{
	int threads = argc > 1 ? atoi(argv[1]) : 0;
	double seconds = argc > 2 ? atof(argv[2]) : 10.0;
	if(threads <= 0)
		threads = (int) sysconf(_SC_NPROCESSORS_ONLN);
	if(threads <= 0) threads = 1;

	pthread_t *tids = calloc(threads, sizeof(pthread_t));
	worker_t *ws = calloc(threads, sizeof(worker_t));

	double t0 = now_sec();
	for(int i = 0; i < threads; i++)
	{
		ws[i].id = i;
		pthread_create(&tids[i], NULL, worker, &ws[i]);
	}
	struct timespec sl = { (time_t) seconds, (long)((seconds - (time_t) seconds) * 1e9) };
	nanosleep(&sl, NULL);
	g_stop = 1;
	uint64_t total = 0, sink = 0;
	for(int i = 0; i < threads; i++)
	{
		pthread_join(tids[i], NULL);
		total += ws[i].units;
		sink ^= ws[i].sink;
	}
	double elapsed = now_sec() - t0;
	double ups = total / elapsed;
	/* 1 work unit ~= 3.2M mixed ALU + FP + branch operations. */
	double points = ups;

	printf("Ionity Bench IO-Core\n");
	printf("Threads: %d  Window: %.2f s  Work units: %llu  (checksum %016llx)\n", threads, elapsed, (unsigned long long) total, (unsigned long long) sink);
	printf("Work units/sec: %.2f\n", ups);
	printf("IONITY_RESULT: %.2f\n", points);
	free(tids); free(ws);
	return 0;
}
IONITY_EOF

if [ "X$CFLAGS_OVERRIDE" = "X" ]; then
    CFLAGS="$CFLAGS -O2"
else
    CFLAGS="$CFLAGS_OVERRIDE"
fi
cc io-core.c $CFLAGS -o io-core-bin -lpthread -lm
CC_EXIT_STATUS=$?
if [ $CC_EXIT_STATUS -gt 0 ]; then
    # Retry without any tuning flags for exotic toolchains
    cc io-core.c -O2 -o io-core-bin -lpthread -lm
    CC_EXIT_STATUS=$?
fi
echo $CC_EXIT_STATUS > ~/install-exit-status

echo "#!/bin/sh
./io-core-bin \$@ 10 > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > io-core
chmod +x io-core
