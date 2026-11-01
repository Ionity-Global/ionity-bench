#!/bin/sh
# Ionity Bench test profile installer - self-contained, no network downloads required.
# (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI | Policy 986 AED | GPL-3.0-or-later

cat > io-latency.c <<'IONITY_EOF'
/*
 * Ionity Bench - IO-Latency-RT
 * Timer wake-up jitter for soft real-time control loops (SCADA / RMS / sensor polling).
 * Copyright (C) 2026 Antwerp Designs | Ionity (Pty) Ltd - AEDI. GPL-3.0-or-later.
 *
 * A single thread sleeps on a fixed period (default 1 ms) for the requested duration
 * and records how late each wake-up arrived relative to the ideal schedule. Results in
 * microseconds, lower is better. Metric selects which statistic is emitted as the result.
 *
 * Usage: io-latency <max|p99|avg> [seconds] [period_us]
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <errno.h>

static inline int64_t ts_to_ns(const struct timespec *t) { return (int64_t) t->tv_sec * 1000000000LL + t->tv_nsec; }
static inline void ns_to_ts(int64_t ns, struct timespec *t) { t->tv_sec = ns / 1000000000LL; t->tv_nsec = ns % 1000000000LL; }

static int cmp_i64(const void *a, const void *b)
{
	int64_t x = *(const int64_t *) a, y = *(const int64_t *) b;
	return (x > y) - (x < y);
}

int main(int argc, char **argv)
{
	const char *metric = argc > 1 ? argv[1] : "max";
	int seconds = argc > 2 ? atoi(argv[2]) : 10;
	int64_t period_ns = (argc > 3 ? atoll(argv[3]) : 1000) * 1000LL;
	if(seconds < 1) seconds = 1;
	if(period_ns < 100000) period_ns = 100000;

	size_t n = (size_t)(seconds * 1000000000LL / period_ns);
	int64_t *lat = malloc(n * sizeof(int64_t));
	if(!lat) return 2;

	struct timespec now, target;
	clock_gettime(CLOCK_MONOTONIC, &now);
	int64_t next = ts_to_ns(&now) + period_ns;
	size_t missed = 0;
	for(size_t i = 0; i < n; i++)
	{
		ns_to_ts(next, &target);
#if defined(__linux__) || defined(__FreeBSD__)
		while(clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &target, NULL) == EINTR) {}
#else
		{
			struct timespec cur, rem;
			clock_gettime(CLOCK_MONOTONIC, &cur);
			int64_t d = next - ts_to_ns(&cur);
			if(d > 0) { ns_to_ts(d, &rem); nanosleep(&rem, NULL); }
		}
#endif
		clock_gettime(CLOCK_MONOTONIC, &now);
		int64_t late = ts_to_ns(&now) - next;
		if(late < 0) late = 0;
		lat[i] = late;
		if(late > period_ns) missed++;
		next += period_ns;
	}

	int64_t sum = 0, max = 0;
	for(size_t i = 0; i < n; i++) { sum += lat[i]; if(lat[i] > max) max = lat[i]; }
	qsort(lat, n, sizeof(int64_t), cmp_i64);
	double avg_us = (double) sum / n / 1000.0;
	double p50_us = lat[n / 2] / 1000.0;
	double p99_us = lat[(size_t)(n * 0.99)] / 1000.0;
	double p999_us = lat[(size_t)(n * 0.999)] / 1000.0;
	double max_us = max / 1000.0;

	printf("Ionity Bench IO-Latency-RT\n");
	printf("Period: %lld us  Samples: %zu  Deadline misses (> period): %zu\n", (long long)(period_ns / 1000), n, missed);
	printf("Wake-up latency (us): avg %.2f  p50 %.2f  p99 %.2f  p99.9 %.2f  max %.2f\n", avg_us, p50_us, p99_us, p999_us, max_us);
	double result = max_us;
	if(!strcasecmp(metric, "p99")) result = p99_us;
	else if(!strcasecmp(metric, "avg")) result = avg_us;
	printf("IONITY_RESULT: %.2f\n", result);
	free(lat);
	return 0;
}
IONITY_EOF

if [ "X$CFLAGS_OVERRIDE" = "X" ]; then
    CFLAGS="$CFLAGS -O2"
else
    CFLAGS="$CFLAGS_OVERRIDE"
fi
cc io-latency.c $CFLAGS -o io-latency-rt-bin -lpthread -lm
CC_EXIT_STATUS=$?
if [ $CC_EXIT_STATUS -gt 0 ]; then
    # Retry without any tuning flags for exotic toolchains
    cc io-latency.c -O2 -o io-latency-rt-bin -lpthread -lm
    CC_EXIT_STATUS=$?
fi
echo $CC_EXIT_STATUS > ~/install-exit-status

echo "#!/bin/sh
./io-latency-rt-bin \$@ 10 1000 > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > io-latency-rt
chmod +x io-latency-rt
