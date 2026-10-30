#ifndef PORT_QSORT_H
#define PORT_QSORT_H

#include <stddef.h>

/* the original C library's qsort (src/port/bsd_qsort.c): same order for equal elements
 * everywhere */
void ivona_qsort(void *base, size_t n, size_t es, int (*cmp)(const void *, const void *));

#endif
