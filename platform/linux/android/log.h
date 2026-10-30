/*
 * Linux stand-in for Android's <android/log.h>, the only Android API the engine uses. On
 * Android its messages go to logcat, where nobody sees them; here they go to stderr, and only
 * when IVONA_LOG is set in the environment.
 */
#ifndef PORT_ANDROID_LOG_H
#define PORT_ANDROID_LOG_H

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum android_LogPriority {
    ANDROID_LOG_UNKNOWN = 0, ANDROID_LOG_DEFAULT, ANDROID_LOG_VERBOSE, ANDROID_LOG_DEBUG,
    ANDROID_LOG_INFO, ANDROID_LOG_WARN, ANDROID_LOG_ERROR, ANDROID_LOG_FATAL, ANDROID_LOG_SILENT
} android_LogPriority;

static inline int __android_log_vprint(int prio, const char *tag, const char *fmt, va_list ap)
{
    int n;

    (void)prio;
    if (!getenv("IVONA_LOG"))
        return 0;
    n = fprintf(stderr, "%s: ", tag);
    return n + vfprintf(stderr, fmt, ap);
}

#ifdef __cplusplus
}
#endif

#endif
