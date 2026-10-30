#ifndef MARK_QUEUE_H
#define MARK_QUEUE_H

#include <stddef.h>
#include "ivona_vector.h"

/* SSML <mark>s waiting to be reported by text position (ssml_doc.c); embedded in the
 * streamer */
typedef struct mark_queue {
    ivona_vector *marks;        /* of ssml_audio */
    size_t next;
} mark_queue;

#endif
