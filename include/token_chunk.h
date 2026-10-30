#ifndef TOKEN_CHUNK_H
#define TOKEN_CHUNK_H

#include "ivona_ustr.h"

/* A run of input tokens synthesized as one utterance (utt_chunk.c); the streamer's chunk vector
 * holds these. One definition for every file that touches them: the decomp's per-file copies
 * only lined up on 32-bit. */
typedef struct token_node token_node;

typedef struct token_chunk {
    token_node *head;
    token_node *tail;
    ustr_span span;             /* input covered */
    int phrasing_model;
    int break_dur_model;
    void *src;                  /* the voice (tts_voice *) */
} token_chunk;

#endif
