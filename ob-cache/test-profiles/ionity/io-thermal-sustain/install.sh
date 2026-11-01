#!/bin/sh
# Ionity Bench test profile installer - self-contained, no network downloads required.
# (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI | Policy 986 AED | GPL-3.0-or-later

cat > io-thermal.c <<'IONITY_EOF'
/*
 * Ionity Bench - IO-Thermal-Sustain
 * Sustained-performance / throttling detector for passively cooled edge hardware.
 * Copyright (C) 2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI. GPL-3.0-or-later.
 *
 * All cores run an FMA-heavy kernel for the requested duration. Throughput is sampled
 * every second. Result = Sustained Efficiency (%):
 *     100 * mean(throughput of the final 20% of samples) / max(throughput of the first 10%)
 * 100% means the device held its peak clock for the whole run; 60% means it throttled
 * to 60% of its initial performance. Also prints peak and sustained GFLOPS and, where
 * available on Linux, the start/end SoC temperature from the thermal zone sysfs.
 *
 * Usage: io-thermal <seconds> [threads|0=all]
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>
#include <math.h>

#define BLOCK_FLOPS (4096.0 * 8.0 * 2.0)

static volatile int g_stop = 0;
typedef struct { volatile uint64_t blocks; int id; double sink; } worker_t;

static double now_sec(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static void *worker(void *arg)
{
	worker_t *w = (worker_t *) arg;
	double a[8], b[8], c[8];
	for(int i = 0; i < 8; i++) { a[i] = 1.0 + i * 0.001 + w->id; b[i] = 0.999; c[i] = 0.0001 * (i + 1); }
	while(!g_stop)
	{
		for(int k = 0; k < 4096; k++)
		{
			for(int i = 0; i < 8; i++)
				a[i] = a[i] * b[i] + c[i];
		}
		w->blocks++;
	}
	double s = 0;
	for(int i = 0; i < 8; i++) s += a[i];
	w->sink = s;
	return NULL;
}

static double read_temp_c(void)
{
	FILE *f = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
	if(!f) return NAN;
	long milli = 0;
	int ok = fscanf(f, "%ld", &milli) == 1;
	fclose(f);
	return ok ? milli / 1000.0 : NAN;
}

int main(int argc, char **argv)
{
	int seconds = argc > 1 ? atoi(argv[1]) : 60;
	if(seconds < 10) seconds = 10;
	int threads = argc > 2 ? atoi(argv[2]) : 0;
	if(threads <= 0) threads = (int) sysconf(_SC_NPROCESSORS_ONLN);
	if(threads <= 0) threads = 1;

	pthread_t *tids = calloc(threads, sizeof(pthread_t));
	worker_t *ws = calloc(threads, sizeof(worker_t));
	double *samples = calloc(seconds, sizeof(double));
	double temp_start = read_temp_c();

	for(int i = 0; i < threads; i++) { ws[i].id = i; pthread_create(&tids[i], NULL, worker, &ws[i]); }

	uint64_t prev = 0;
	double t_prev = now_sec();
	for(int s = 0; s < seconds; s++)
	{
		sleep(1);
		uint64_t cur = 0;
		for(int i = 0; i < threads; i++) cur += ws[i].blocks;
		double t = now_sec();
		samples[s] = (cur - prev) * BLOCK_FLOPS / (t - t_prev) / 1e9; /* GFLOPS this second */
		prev = cur; t_prev = t;
	}
	g_stop = 1;
	double sink = 0;
	for(int i = 0; i < threads; i++) { pthread_join(tids[i], NULL); sink += ws[i].sink; }
	double temp_end = read_temp_c();

	int head = seconds / 10; if(head < 2) head = 2;
	int tail = seconds / 5;  if(tail < 2) tail = 2;
	double peak = 0, sustained = 0, mean = 0;
	for(int s = 0; s < head; s++) if(samples[s] > peak) peak = samples[s];
	for(int s = seconds - tail; s < seconds; s++) sustained += samples[s];
	sustained /= tail;
	for(int s = 0; s < seconds; s++) mean += samples[s];
	mean /= seconds;
	double efficiency = peak > 0 ? 100.0 * sustained / peak : 0;
	if(efficiency > 100.0) efficiency = 100.0;

	printf("Ionity Bench IO-Thermal-Sustain\n");
	printf("Threads: %d  Duration: %d s  (checksum %.6e)\n", threads, seconds, sink);
	printf("Peak GFLOPS (first %d s): %.3f\n", head, peak);
	printf("Sustained GFLOPS (last %d s): %.3f\n", tail, sustained);
	printf("Mean GFLOPS: %.3f\n", mean);
	if(!isnan(temp_start) && !isnan(temp_end))
		printf("SoC temperature: %.1f C -> %.1f C (delta %.1f C)\n", temp_start, temp_end, temp_end - temp_start);
	printf("Per-second GFLOPS:");
	for(int s = 0; s < seconds; s++) printf(" %.2f", samples[s]);
	printf("\n");
	printf("IONITY_SUSTAINED_GFLOPS: %.3f\n", sustained);
	printf("IONITY_RESULT: %.2f\n", efficiency);
	free(tids); free(ws); free(samples);
	return 0;
}
IONITY_EOF

if [ "X$CFLAGS_OVERRIDE" = "X" ]; then
    CFLAGS="$CFLAGS -O2"
else
    CFLAGS="$CFLAGS_OVERRIDE"
fi
cc io-thermal.c $CFLAGS -o io-thermal-sustain-bin -lpthread -lm
CC_EXIT_STATUS=$?
if [ $CC_EXIT_STATUS -gt 0 ]; then
    # Retry without any tuning flags for exotic toolchains
    cc io-thermal.c -O2 -o io-thermal-sustain-bin -lpthread -lm
    CC_EXIT_STATUS=$?
fi
echo $CC_EXIT_STATUS > ~/install-exit-status

echo "#!/bin/sh
./io-thermal-sustain-bin \$@ 0 > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > io-thermal-sustain
chmod +x io-thermal-sustain
