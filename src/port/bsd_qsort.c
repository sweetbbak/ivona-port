/*
 * The qsort of the original's C library (Android's bionic, from 4.4BSD/FreeBSD: Bentley &
 * McIlroy, "Engineering a Sort Function"), so that elements comparing equal end up in the same
 * order on every platform. IVONA sorts unit candidates by cost, and ties are common; glibc's
 * merge sort orders them differently and changes which units get selected.
 */
#include <stddef.h>
#include "port_qsort.h"

typedef int cmp_t(const void *, const void *);

static void swapbytes(char *a, char *b, size_t n)
{
    char t;

    while (n--) {
        t = *a;
        *a++ = *b;
        *b++ = t;
    }
}

#define swap(a, b) swapbytes((a), (b), es)
#define vecswap(a, b, n) do { if ((n) > 0) swapbytes((a), (b), (n)); } while (0)
#define MIN(a, b) ((a) < (b) ? (a) : (b))

static char *med3(char *a, char *b, char *c, cmp_t *cmp)
{
    return cmp(a, b) < 0 ? (cmp(b, c) < 0 ? b : (cmp(a, c) < 0 ? c : a))
                         : (cmp(b, c) > 0 ? b : (cmp(a, c) < 0 ? a : c));
}

void ivona_qsort(void *base, size_t n, size_t es, int (*cmp)(const void *, const void *))
{
    char *a = base, *pa, *pb, *pc, *pd, *pl, *pm, *pn;
    size_t r;
    int cmp_result, swap_cnt;

loop:
    swap_cnt = 0;
    if (n < 7) {
        for (pm = a + es; pm < a + n * es; pm += es)
            for (pl = pm; pl > a && cmp(pl - es, pl) > 0; pl -= es)
                swap(pl, pl - es);
        return;
    }
    pm = a + (n / 2) * es;
    if (n > 7) {
        pl = a;
        pn = a + (n - 1) * es;
        if (n > 40) {
            size_t d = (n / 8) * es;

            pl = med3(pl, pl + d, pl + 2 * d, cmp);
            pm = med3(pm - d, pm, pm + d, cmp);
            pn = med3(pn - 2 * d, pn - d, pn, cmp);
        }
        pm = med3(pl, pm, pn, cmp);
    }
    swap(a, pm);
    pa = pb = a + es;
    pc = pd = a + (n - 1) * es;
    for (;;) {
        while (pb <= pc && (cmp_result = cmp(pb, a)) <= 0) {
            if (cmp_result == 0) {
                swap_cnt = 1;
                swap(pa, pb);
                pa += es;
            }
            pb += es;
        }
        while (pb <= pc && (cmp_result = cmp(pc, a)) >= 0) {
            if (cmp_result == 0) {
                swap_cnt = 1;
                swap(pc, pd);
                pd -= es;
            }
            pc -= es;
        }
        if (pb > pc)
            break;
        swap(pb, pc);
        swap_cnt = 1;
        pb += es;
        pc -= es;
    }
    if (swap_cnt == 0) {        /* switch to insertion sort */
        for (pm = a + es; pm < a + n * es; pm += es)
            for (pl = pm; pl > a && cmp(pl - es, pl) > 0; pl -= es)
                swap(pl, pl - es);
        return;
    }
    pn = a + n * es;
    r = MIN((size_t)(pa - a), (size_t)(pb - pa));
    vecswap(a, pb - r, r);
    r = MIN((size_t)(pd - pc), (size_t)(pn - pd) - es);
    vecswap(pb, pn - r, r);
    if ((r = pb - pa) > es)
        ivona_qsort(a, r / es, es, cmp);
    if ((r = pd - pc) > es) {
        /* iterate rather than recurse */
        a = pn - r;
        n = r / es;
        goto loop;
    }
}
