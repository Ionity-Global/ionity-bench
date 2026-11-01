#!/bin/sh
# Ionity Bench test profile installer - self-contained, no network downloads required.
# (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI | Policy 986 AED | GPL-3.0-or-later

cat > io-matmul.c <<'IONITY_EOF'
/*
 * Ionity Bench - IO-AI-MatMul
 * Edge-inference proxy: blocked GEMM in FP32 and INT8 (int32 accumulate) with pthreads.
 * Copyright (C) 2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI. GPL-3.0-or-later.
 *
 * Dense matrix multiply is the dominant primitive behind CNN / transformer inference on
 * CPUs without an NPU, and INT8 is the quantised path used by TFLite / ONNX Runtime on
 * edge devices. Matrices are 512x512 (fits typical SBC L2+L3), blocked 64x64, rows split
 * across threads, repeated for ~8 seconds. Result: GFLOPS (FP32) or GOPS (INT8).
 *
 * Usage: io-matmul <fp32|int8> [threads|0=all] [n]
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>

#define BLK 64
static int g_n, g_threads, g_int8;
static float *fa, *fb, *fc;
static int8_t *ia, *ib;
static int32_t *ic;

static double now_sec(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static void *gemm_rows(void *arg)
{
	long id = (long) arg;
	int n = g_n;
	int lo = n * id / g_threads, hi = n * (id + 1) / g_threads;
	if(!g_int8)
	{
		for(int i0 = lo; i0 < hi; i0 += BLK)
		for(int k0 = 0; k0 < n; k0 += BLK)
		for(int j0 = 0; j0 < n; j0 += BLK)
		{
			int i1 = i0 + BLK < hi ? i0 + BLK : hi;
			for(int i = i0; i < i1; i++)
			for(int k = k0; k < k0 + BLK; k++)
			{
				float a = fa[i * n + k];
				const float *brow = &fb[k * n + j0];
				float *crow = &fc[i * n + j0];
				for(int j = 0; j < BLK; j++) crow[j] += a * brow[j];
			}
		}
	}
	else
	{
		for(int i0 = lo; i0 < hi; i0 += BLK)
		for(int k0 = 0; k0 < n; k0 += BLK)
		for(int j0 = 0; j0 < n; j0 += BLK)
		{
			int i1 = i0 + BLK < hi ? i0 + BLK : hi;
			for(int i = i0; i < i1; i++)
			for(int k = k0; k < k0 + BLK; k++)
			{
				int32_t a = ia[i * n + k];
				const int8_t *brow = &ib[k * n + j0];
				int32_t *crow = &ic[i * n + j0];
				for(int j = 0; j < BLK; j++) crow[j] += a * (int32_t) brow[j];
			}
		}
	}
	return NULL;
}

int main(int argc, char **argv)
{
	g_int8 = argc > 1 && !strcasecmp(argv[1], "int8");
	g_threads = argc > 2 ? atoi(argv[2]) : 0;
	if(g_threads <= 0) g_threads = (int) sysconf(_SC_NPROCESSORS_ONLN);
	if(g_threads <= 0) g_threads = 1;
	g_n = argc > 3 ? atoi(argv[3]) : 512;
	if(g_n % BLK) g_n = (g_n / BLK + 1) * BLK;
	int n = g_n;
	size_t cells = (size_t) n * n;

	if(!g_int8)
	{
		fa = malloc(cells * 4); fb = malloc(cells * 4); fc = calloc(cells, 4);
		for(size_t i = 0; i < cells; i++) { fa[i] = (float)((i * 7) % 13) / 13.0f; fb[i] = (float)((i * 5) % 11) / 11.0f; }
	}
	else
	{
		ia = malloc(cells); ib = malloc(cells); ic = calloc(cells, 4);
		for(size_t i = 0; i < cells; i++) { ia[i] = (int8_t)((i * 7) % 127 - 63); ib[i] = (int8_t)((i * 5) % 127 - 63); }
	}

	pthread_t *t = calloc(g_threads, sizeof(pthread_t));
	double ops_per = 2.0 * (double) n * n * n;
	double window = 8.0, t0 = now_sec(), best = 1e30;
	int iters = 0;
	while(now_sec() - t0 < window || iters < 3)
	{
		double s = now_sec();
		for(long i = 0; i < g_threads; i++) pthread_create(&t[i], NULL, gemm_rows, (void *) i);
		for(int i = 0; i < g_threads; i++) pthread_join(t[i], NULL);
		double dt = now_sec() - s;
		if(dt < best) best = dt;
		iters++;
	}
	double gops = ops_per / best / 1e9;
	double check = g_int8 ? (double) ic[cells / 2] : (double) fc[cells / 2];

	printf("Ionity Bench IO-AI-MatMul\n");
	printf("Precision: %s  N: %d  Threads: %d  Iterations: %d  Best: %.4f s  (check %.3f)\n", g_int8 ? "INT8" : "FP32", n, g_threads, iters, best, check);
	printf("IONITY_RESULT: %.3f\n", gops);
	return 0;
}
IONITY_EOF

if [ "X$CFLAGS_OVERRIDE" = "X" ]; then
    CFLAGS="$CFLAGS -O2"
else
    CFLAGS="$CFLAGS_OVERRIDE"
fi
cc io-matmul.c $CFLAGS -o io-ai-matmul-bin -lpthread -lm
CC_EXIT_STATUS=$?
if [ $CC_EXIT_STATUS -gt 0 ]; then
    # Retry without any tuning flags for exotic toolchains
    cc io-matmul.c -O2 -o io-ai-matmul-bin -lpthread -lm
    CC_EXIT_STATUS=$?
fi
echo $CC_EXIT_STATUS > ~/install-exit-status

echo "#!/bin/sh
./io-ai-matmul-bin \$@ 0 512 > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > io-ai-matmul
chmod +x io-ai-matmul
