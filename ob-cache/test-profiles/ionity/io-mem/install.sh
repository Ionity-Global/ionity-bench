#!/bin/sh
# Ionity Bench test profile installer - self-contained, no network downloads required.
# (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI | Policy 986 AED | GPL-3.0-or-later

cat > io-mem.c <<'IONITY_EOF'
/*
 * Ionity Bench - IO-Mem
 * STREAM-style sustained memory bandwidth (Copy / Scale / Add / Triad) using pthreads.
 * Copyright (C) 2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI. GPL-3.0-or-later.
 *
 * Array size is auto-selected as 4x the last-level cache (minimum 64 MiB per array,
 * capped at 1/8 of physical RAM so SBCs with 1-2 GB survive). Best-of-N timing
 * mirrors the classic STREAM methodology.
 *
 * Usage: io-mem <Copy|Scale|Add|Triad> [threads|0=all] [repeats]
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>

typedef double real;
static real *A, *B, *C;
static size_t N;
static int g_threads;
static int g_kernel;

static double now_sec(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static void *run_chunk(void *arg)
{
	long id = (long) arg;
	size_t lo = N * id / g_threads, hi = N * (id + 1) / g_threads;
	const real scalar = 3.0;
	switch(g_kernel)
	{
		case 0: for(size_t i = lo; i < hi; i++) C[i] = A[i]; break;
		case 1: for(size_t i = lo; i < hi; i++) B[i] = scalar * C[i]; break;
		case 2: for(size_t i = lo; i < hi; i++) C[i] = A[i] + B[i]; break;
		case 3: for(size_t i = lo; i < hi; i++) A[i] = B[i] + scalar * C[i]; break;
	}
	return NULL;
}

static void *init_chunk(void *arg)
{
	long id = (long) arg;
	size_t lo = N * id / g_threads, hi = N * (id + 1) / g_threads;
	for(size_t i = lo; i < hi; i++) { A[i] = 1.0; B[i] = 2.0; C[i] = 0.0; }
	return NULL;
}

static void parallel(void *(*fn)(void *))
{
	pthread_t *t = calloc(g_threads, sizeof(pthread_t));
	for(long i = 0; i < g_threads; i++) pthread_create(&t[i], NULL, fn, (void *) i);
	for(int i = 0; i < g_threads; i++) pthread_join(t[i], NULL);
	free(t);
}

static size_t pick_array_bytes(void)
{
	long l3 = 0;
#ifdef _SC_LEVEL3_CACHE_SIZE
	l3 = sysconf(_SC_LEVEL3_CACHE_SIZE);
#endif
	long l2 = 0;
#ifdef _SC_LEVEL2_CACHE_SIZE
	l2 = sysconf(_SC_LEVEL2_CACHE_SIZE);
#endif
	long llc = l3 > 0 ? l3 : l2;
	size_t bytes = 64UL << 20;
	if(llc > 0 && (size_t) llc * 4 > bytes) bytes = (size_t) llc * 4;
	long pages = sysconf(_SC_PHYS_PAGES), psz = sysconf(_SC_PAGESIZE);
	if(pages > 0 && psz > 0)
	{
		size_t cap = ((size_t) pages * (size_t) psz) / 8 / 3; /* three arrays, <= 1/8 RAM total */
		if(cap < (16UL << 20)) cap = 16UL << 20;
		if(bytes > cap) bytes = cap;
	}
	return bytes;
}

int main(int argc, char **argv)
{
	const char *names[] = { "Copy", "Scale", "Add", "Triad" };
	const double bytes_per[] = { 2, 2, 3, 3 };
	g_kernel = -1;
	if(argc > 1)
		for(int k = 0; k < 4; k++) if(!strcasecmp(argv[1], names[k])) g_kernel = k;
	if(g_kernel < 0) { fprintf(stderr, "usage: io-mem <Copy|Scale|Add|Triad> [threads] [repeats]\n"); return 1; }
	g_threads = argc > 2 ? atoi(argv[2]) : 0;
	if(g_threads <= 0) g_threads = (int) sysconf(_SC_NPROCESSORS_ONLN);
	if(g_threads <= 0) g_threads = 1;
	int repeats = argc > 3 ? atoi(argv[3]) : 20;

	size_t bytes = pick_array_bytes();
	N = bytes / sizeof(real);
	A = malloc(bytes); B = malloc(bytes); C = malloc(bytes);
	if(!A || !B || !C) { fprintf(stderr, "allocation failed\n"); return 2; }
	parallel(init_chunk);
	parallel(run_chunk); /* warm-up */

	double best = 1e30, sum = 0;
	for(int r = 0; r < repeats; r++)
	{
		double t0 = now_sec();
		parallel(run_chunk);
		double dt = now_sec() - t0;
		if(dt < best) best = dt;
		sum += dt;
	}
	double mbps = (bytes_per[g_kernel] * (double) bytes) / best / 1e6;
	printf("Ionity Bench IO-Mem\n");
	printf("Kernel: %s  Threads: %d  Array: %.1f MiB x3  Repeats: %d\n", names[g_kernel], g_threads, bytes / 1048576.0, repeats);
	printf("Best time: %.6f s  Avg time: %.6f s  Check: %.3f\n", best, sum / repeats, A[N / 2] + B[N / 2] + C[N / 2]);
	printf("IONITY_RESULT: %.1f\n", mbps);
	free(A); free(B); free(C);
	return 0;
}
IONITY_EOF

if [ "X$CFLAGS_OVERRIDE" = "X" ]; then
    CFLAGS="$CFLAGS -O2"
else
    CFLAGS="$CFLAGS_OVERRIDE"
fi
cc io-mem.c $CFLAGS -o io-mem-bin -lpthread -lm
CC_EXIT_STATUS=$?
if [ $CC_EXIT_STATUS -gt 0 ]; then
    # Retry without any tuning flags for exotic toolchains
    cc io-mem.c -O2 -o io-mem-bin -lpthread -lm
    CC_EXIT_STATUS=$?
fi
echo $CC_EXIT_STATUS > ~/install-exit-status

echo "#!/bin/sh
./io-mem-bin \$@ 0 20 > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > io-mem
chmod +x io-mem
